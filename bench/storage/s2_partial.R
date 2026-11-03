source("storage/_storage.R")
suppressPackageStartupMessages({library(dplyr)})
RSS_RES <- "storage/results/storage_rss.csv"
S2 <- file.path(SCRATCH, "s2"); dir.create(S2, showWarnings = FALSE)
CUT <- 10000L
QT <- min(4L, bench_cores())  # qs2 threads for the multi-thread variants
# Peak RSS of a fresh R child, sampled every 10 ms with ps (peak working set on Windows).
peak_rss <- function(m, p, fcol, cols, th = NULL) {
  env <- c("current", THREADS = if (is.null(th)) "" else as.character(th), CUT = as.character(CUT), QS_NT = as.character(QT),
           R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  out <- tempfile(fileext = ".txt"); on.exit(unlink(out), add = TRUE)
  pr <- processx::process$new(rscript_bin(), c("storage/_rss_child.R", m, p, fcol, paste(cols, collapse = ",")), env = env, stdout = out, stderr = "2>&1")
  h <- pr$as_ps_handle(); peak <- 0
  while (pr$is_alive()) {
    mi <- tryCatch(ps::ps_memory_info(h), error = function(e) NULL)
    if (!is.null(mi)) peak <- max(peak, mi[["rss"]], if ("peak_wset" %in% names(mi)) mi[["peak_wset"]] else 0)
    Sys.sleep(0.01)
  }
  if (pr$get_exit_status() != 0) stop("rss child failed: ", paste(utils::tail(readLines(out), 5), collapse = " "))
  peak / 2^20
}
add_rss <- function(tag, n, rows) { # rows: data.frame(method, peak_mb)
  out <- data.frame(topic = "storage", task = tag, n = n, method = rows$method, peak_rss_mb = rows$peak_mb,
    baseline_rss_mb = rows$base_mb, net_rss_mb = rows$peak_mb - rows$base_mb, notes = "max RSS of fresh R process, ps sampled every 10 ms; net = minus baseline (libs loaded, no read)")
  write_result(cbind(out, bench_env()), RSS_RES)
}

run_obj <- function(x, tag, fcol, cols, n) {
  stopifnot(fcol %in% names(x)); CUT <<- as.integer(quantile(x[[fcol]], 0.01)); Sys.setenv(CUT = CUT)
  ref_n <- sum(x[[fcol]] <= CUT)
  d <- file.path(S2, tag); dir.create(d, showWarnings = FALSE)
  qsf <- file.path(d, "full.qs2"); qs2::qs_save(x, qsf, nthreads = QT)
  # parquet variants written by duckdb
  vars <- expand.grid(rg = c(1e4, 122880, 1e6), sorted = c(FALSE, TRUE))
  for (i in seq_len(nrow(vars))) {
    f <- file.path(d, sprintf("rg%d_%s.parquet", vars$rg[i], if (vars$sorted[i]) "sorted" else "unsorted"))
    duck_write(x, f, rg = vars$rg[i], order_by = if (vars$sorted[i]) fcol)
  }
  pq <- \(rg, s) file.path(d, sprintf("rg%d_%s.parquet", rg, s))
  p0 <- pq(122880, "unsorted")
  message(tag, " parquet sizes MB: ", paste(round(file.size(list.files(d, full.names = TRUE)) / 2^20), collapse = " "))
  rec <- function(mk, task, same) { tmp <- tempfile(); o <- record_mark(mk, "storage", task, n, tmp, STORAGE_PKGS, same = same); unlink(tmp)
    o$file_mb <- NA_real_; o$equal_ignoring_attrs <- NA; write_result(o, RES); print(o[, c("task", "method", "median_s", "ratio_to_fastest", "identical_to_ref")], row.names = FALSE) }
  # column subset
  cs <- cols
  fns <- list(
    qs2_full_then_subset = \() qs2::qs_read(qsf, nthreads = QT)[, cs],
    qs2_t1_full_then_subset = \() qs2::qs_read(qsf, nthreads = 1)[, cs],
    np_full_then_subset = \() nanoparquet::read_parquet(p0)[, cs],
    np_col_select = \() nanoparquet::read_parquet(p0, col_select = cs),
    arrow_col_select = \() arrow::read_parquet(p0, col_select = cs),
    arrow_col_select_1t = \() { arrow_threads(1); arrow::read_parquet(p0, col_select = cs) },
    duck_select = \() duck_read_q(sprintf("SELECT %s FROM read_parquet('%s')", paste(cs, collapse = ","), p0)),
    duck_select_1t = \() duck_read_q(sprintf("SELECT %s FROM read_parquet('%s')", paste(cs, collapse = ","), p0), 1))
  ref <- as.data.frame(x[, cs])
  same <- vapply(fns, \(f) { r <- as.data.frame(f()); isTRUE(all.equal(ref, r, check.attributes = FALSE)) }, NA)
  mk <- bench::mark(exprs = setNames(lapply(names(fns), \(k) bquote(fns[[.(k)]]())), names(fns)), iterations = ITER, check = FALSE, memory = FALSE, env = environment())
  rec(mk, paste0(tag, "_partial_cols"), same)
  # row filter
  for (rg in c(1e4, 122880, 1e6)) for (s in c("unsorted", "sorted")) {
    f <- pq(rg, s)
    ff <- list(
      arrow_open_dataset_filter = \() arrow::open_dataset(f) |> filter(.data[[fcol]] <= CUT) |> collect(),
      arrow_filter_1t = \() { arrow_threads(1); arrow::open_dataset(f) |> filter(.data[[fcol]] <= CUT) |> collect() },
      duck_where = \() duck_read_q(sprintf("SELECT * FROM read_parquet('%s') WHERE %s <= %d", f, fcol, CUT)),
      duck_where_1t = \() duck_read_q(sprintf("SELECT * FROM read_parquet('%s') WHERE %s <= %d", f, fcol, CUT), 1),
      np_full_then_filter = \() { d <- nanoparquet::read_parquet(f); d[d[[fcol]] <= CUT, ] })
    if (rg == 122880 && s == "unsorted") ff$qs2_full_then_filter <- \() { d <- qs2::qs_read(qsf, nthreads = QT); d[d[[fcol]] <= CUT, ] }
    same <- vapply(ff, \(g) NROW(g()) == ref_n, NA)
    mk <- bench::mark(exprs = setNames(lapply(names(ff), \(k) bquote(ff[[.(k)]]())), names(ff)), iterations = ITER, check = FALSE, memory = FALSE, env = environment())
    rec(mk, sprintf("%s_partial_filter_rg%d_%s", tag, rg, s), same)
  }
  # peak memory (fresh processes)
  base <- peak_rss("baseline", p0, fcol, cs)
  jobs <- list(
    list("qs2_full", qsf, NULL), list("qs2_full_cols", qsf, NULL), list("qs2_full_cols", qsf, 1),
    list("np_full", p0, NULL), list("np_cols", p0, NULL), list("arrow_full", p0, NULL), list("arrow_cols", p0, NULL), list("duck_cols", p0, NULL),
    list("duck_cols", p0, 1), list("arrow_cols", p0, 1),
    list("arrow_filter", pq(122880, "unsorted"), NULL), list("duck_filter", pq(122880, "unsorted"), NULL),
    list("arrow_filter", pq(122880, "sorted"), NULL), list("duck_filter", pq(122880, "sorted"), NULL),
    list("np_full_filter", pq(122880, "sorted"), NULL), list("qs2_full_filter", qsf, NULL))
  rr <- do.call(rbind, lapply(jobs, \(j) { pk <- peak_rss(j[[1]], j[[2]], fcol, cs, j[[3]]); data.frame(method = paste0(j[[1]], if (!is.null(j[[3]])) "_1t" else "", "@", sub("^.*/", "", j[[2]])), peak_mb = pk, base_mb = base) }))
  add_rss(paste0(tag, "_peak_rss_read"), n, rr); print(transform(rr, net_mb = round(peak_mb - base_mb)), row.names = FALSE)
  unlink(d, recursive = TRUE)
}
duck_read_q <- function(sql, threads = NULL) { con <- duck_con(threads); on.exit(DBI::dbDisconnect(con, shutdown = TRUE)); DBI::dbGetQuery(con, sql) }

if (fits_or_skip(150, 5, "s2 a")) { a <- make_a(2.5e6L); run_obj(a, "a", "i1", c("x1", "i1"), 2.5e6); rm(a); gc() }
if (fits_or_skip(150, 5, "s2 b")) { b <- make_b(1.5e5L); b$key <- sample.int(nrow(b)); run_obj(b, "b", "key", c("id", "day"), 1.5e5); rm(b); gc() }

unlink(S2, recursive = TRUE)
