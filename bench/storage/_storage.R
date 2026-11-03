Sys.setenv(ARROW_DEFAULT_MEMORY_POOL = "system")
source("_common.R")
suppressPackageStartupMessages({library(bench); library(tibble)})

SCRATCH <- bench_scratch("b3")
dir.create(SCRATCH, showWarnings = FALSE, recursive = TRUE)
STORAGE_PKGS <- c("qs2", "zap", "fst", "nanoparquet", "arrow", "duckdb", "bench")
# zap needs a patched build on R >= 4.6 and fst may fail to load; run without them.
STORAGE_PKGS <- STORAGE_PKGS[vapply(STORAGE_PKGS, requireNamespace, logical(1), quietly = TRUE)]
RES <- "storage/results/storage.csv"
ITER <- 3L

duck_con <- function(threads = NULL) {
  con <- DBI::dbConnect(duckdb::duckdb())
  DBI::dbExecute(con, "SET memory_limit='1GB'")
  if (!is.null(threads)) DBI::dbExecute(con, paste0("SET threads=", threads))
  con
}
# Set arrow's thread count and restore the previous value when the calling function exits.
arrow_threads <- function(n, env = parent.frame()) {
  old <- arrow::cpu_count()
  arrow::set_cpu_count(n)
  do.call(on.exit, list(bquote(arrow::set_cpu_count(.(old))), TRUE), envir = env)
  invisible(old)
}

# Thread count for the "_t4" methods; they are skipped when fewer than 4 cores are available.
NT4 <- 4L
duck_write <- function(x, path, rg = NULL, order_by = NULL, threads = NULL) {
  con <- duck_con(threads); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  duckdb::duckdb_register(con, "t", x)
  q <- sprintf("COPY (SELECT * FROM t%s) TO '%s' (FORMAT parquet, COMPRESSION zstd%s)",
    if (is.null(order_by)) "" else paste(" ORDER BY", order_by), path,
    if (is.null(rg)) "" else paste0(", ROW_GROUP_SIZE ", rg))
  DBI::dbExecute(con, q)
}
duck_read <- function(path, threads = NULL) {
  con <- duck_con(threads); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, sprintf("SELECT * FROM read_parquet('%s')", path))
}

# method: list(write, read, ext). Each fn(obj,path) / fn(path).
M_ALL <- list(
  rds_gzip   = list(w = \(x, p) saveRDS(x, p), r = readRDS, ext = "rds"),
  rds_none   = list(w = \(x, p) saveRDS(x, p, compress = FALSE), r = readRDS, ext = "rds"),
  qs2_t1     = list(w = \(x, p) qs2::qs_save(x, p, nthreads = 1), r = \(p) qs2::qs_read(p, nthreads = 1), ext = "qs2"),
  qs2_t4     = list(w = \(x, p) qs2::qs_save(x, p, nthreads = 4), r = \(p) qs2::qs_read(p, nthreads = 4), ext = "qs2"),
  qs2_t1_l1  = list(w = \(x, p) qs2::qs_save(x, p, compress_level = 1, nthreads = 1), r = \(p) qs2::qs_read(p, nthreads = 1), ext = "qs2"),
  qs2_t4_l1  = list(w = \(x, p) qs2::qs_save(x, p, compress_level = 1, nthreads = 4), r = \(p) qs2::qs_read(p, nthreads = 4), ext = "qs2"),
  qd_t1      = list(w = \(x, p) qs2::qd_save(x, p, nthreads = 1), r = \(p) qs2::qd_read(p, nthreads = 1), ext = "qdata"),
  qd_t4      = list(w = \(x, p) qs2::qd_save(x, p, nthreads = 4), r = \(p) qs2::qd_read(p, nthreads = 4), ext = "qdata"),
  qd_t1_noalt = list(w = \(x, p) qs2::qd_save(x, p, nthreads = 1), r = \(p) qs2::qd_read(p, use_alt_rep = FALSE, nthreads = 1), ext = "qdata"),
  zap        = list(w = \(x, p) zap::zap_write(x, p), r = \(p) zap::zap_read(p), ext = "zap"),
  fst        = list(w = \(x, p) fst::write_fst(x, p), r = \(p) fst::read_fst(p), ext = "fst"),
  fst_c0     = list(w = \(x, p) fst::write_fst(x, p, compress = 0), r = \(p) fst::read_fst(p), ext = "fst"),
  np_snappy  = list(w = \(x, p) nanoparquet::write_parquet(x, p, compression = "snappy"), r = \(p) nanoparquet::read_parquet(p), ext = "parquet"),
  np_zstd    = list(w = \(x, p) nanoparquet::write_parquet(x, p, compression = "zstd"), r = \(p) nanoparquet::read_parquet(p), ext = "parquet"),
  arrow_snappy = list(w = \(x, p) arrow::write_parquet(x, p, compression = "snappy"), r = \(p) arrow::read_parquet(p), ext = "parquet"),
  arrow_zstd = list(w = \(x, p) arrow::write_parquet(x, p, compression = "zstd"), r = \(p) arrow::read_parquet(p), ext = "parquet"),
  duck_zstd  = list(w = \(x, p) duck_write(x, p), r = duck_read, ext = "parquet"),
  arrow_zstd_1t = list(w = \(x, p) { arrow_threads(1); arrow::write_parquet(x, p, compression = "zstd") },
    r = \(p) { arrow_threads(1); arrow::read_parquet(p) }, ext = "parquet"),
  duck_zstd_1t = list(w = \(x, p) duck_write(x, p, threads = 1), r = \(p) duck_read(p, threads = 1), ext = "parquet")
)
# Drop methods whose package is missing (scripts pass method names, so filter there too).
method_pkg <- function(m) if (startsWith(m, "zap")) "zap" else if (startsWith(m, "fst")) "fst" else NA
available_methods <- function(methods) {
  keep <- vapply(methods, \(m) (is.na(method_pkg(m)) || method_pkg(m) %in% STORAGE_PKGS) &&
                 (!grepl("_t4", m) || bench_cores() >= NT4), logical(1))
  if (any(!keep & grepl("_t4", methods)) && bench_cores() < NT4) message("skipping _t4 methods: fewer than ", NT4, " cores")
  methods[keep]
}

# Run write+read benchmark for one object. Writes rows for tasks "<tag>_write", "<tag>_read".
bench_object <- function(x, tag, methods, n, check = identical, notes = "") {
  methods <- available_methods(methods)
  td <- file.path(SCRATCH, tag); dir.create(td, showWarnings = FALSE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  paths <- setNames(file.path(td, paste0(methods, ".", vapply(M_ALL[methods], `[[`, "", "ext"))), methods)
  ok <- setNames(rep(TRUE, length(methods)), methods); err <- setNames(rep("", length(methods)), methods)
  # write
  for (m in methods) {
    r <- tryCatch({ suppressWarnings(M_ALL[[m]]$w(x, paths[[m]])); NULL }, error = \(e) conditionMessage(e))
    if (!is.null(r)) { ok[m] <- FALSE; err[m] <- r; message("WRITE FAIL ", tag, " ", m, ": ", r) }
  }
  good <- names(ok)[ok]
  size_mb <- vapply(good, \(m) file.size(paths[[m]]) / 2^20, 0)
  wexprs <- setNames(lapply(good, \(m) bquote(M_ALL[[.(m)]]$w(x, paths[[.(m)]]))), good)
  wm <- bench::mark(exprs = wexprs, iterations = ITER, check = FALSE, memory = FALSE, env = environment())
  # read + fidelity
  same <- setNames(rep(NA, length(good)), good); eq <- same; rd_ok <- setNames(rep(TRUE, length(good)), good)
  for (m in good) {
    res <- tryCatch(suppressWarnings(M_ALL[[m]]$r(paths[[m]])), error = \(e) e)
    if (inherits(res, "error")) { rd_ok[m] <- FALSE; err[m] <- conditionMessage(res); next }
    same[m] <- isTRUE(check(x, res))
    eq[m] <- isTRUE(all.equal(x, res, check.attributes = FALSE))
    rm(res)
  }
  rgood <- names(rd_ok)[rd_ok]
  rexprs <- setNames(lapply(rgood, \(m) bquote({r <- M_ALL[[.(m)]]$r(paths[[.(m)]]); NULL})), rgood)
  rm_ <- bench::mark(exprs = rexprs, iterations = ITER, check = FALSE, memory = FALSE, env = environment())
  for (kind in c("write", "read")) {
    mk <- if (kind == "write") wm else rm_
    tmp <- tempfile(fileext = ".csv")
    out <- record_mark(mk, "storage", paste0(tag, "_", kind), n, tmp, STORAGE_PKGS, same = same, notes = notes)
    unlink(tmp)
    out$file_mb <- round(size_mb[out$method], 2)
    out$equal_ignoring_attrs <- eq[out$method]
    write_result(out, RES)
  }
  failed <- names(ok)[!ok | names(ok) %in% names(rd_ok)[!rd_ok]]
  if (length(failed)) {
    out <- data.frame(topic = "storage", task = paste0(tag, "_write"), n = n, method = failed,
      median_s = NA_real_, ratio_to_fastest = NA_real_, mem_alloc_mb = NA_real_, n_itr = 0L,
      identical_to_ref = NA, notes = paste("FAILED:", substr(gsub("[\r\n,]+", " ", err[failed]), 1, 120)),
      packages = pkg_versions(STORAGE_PKGS))
    out <- cbind(out, bench_env()); out$file_mb <- NA_real_; out$equal_ignoring_attrs <- NA
    write_result(out, RES)
  }
  rr <- data.frame(method = good, size_mb = round(size_mb, 1), write_s = round(as.numeric(wm$median), 2),
    read_s = round(as.numeric(rm_$median)[match(good, as.character(rm_$expression))], 2), identical = same[good], equal_ignoring_attrs = eq[good])
  print(rr, row.names = FALSE)
  invisible(rr)
}

make_a <- function(n = 1e7L) {
  set.seed(1)
  df <- data.frame(x1 = rnorm(n), x2 = runif(n), x3 = rnorm(n), x4 = runif(n), x5 = rnorm(n),
    i1 = sample.int(1e6L, n, TRUE), i2 = sample.int(100L, n, TRUE), i3 = sample.int(1e9L, n, TRUE),
    i4 = sample.int(10L, n, TRUE), i5 = seq_len(n))
  df
}

make_b <- function(n = 1e6L, words = 115L) {
  set.seed(2)
  vocab <- vapply(1:5000, \(i) paste(sample(letters, sample(3:10, 1), TRUE), collapse = ""), "")
  prob <- 1 / seq_along(vocab)
  pool <- vapply(1:20000, \(i) paste(sample(vocab, words, TRUE, prob), collapse = " "), "")
  tibble(id = seq_len(n),
    uid = sprintf("%08x-%04x", sample.int(.Machine$integer.max, n), sample.int(65535L, n, TRUE)),
    grp = factor(sample(sprintf("grp%02d", 1:20), n, TRUE)),
    day = as.Date("2020-01-01") + sample.int(1500L, n, TRUE),
    text = sample(pool, n, TRUE))
}
