source("storage/_storage.R")
set.seed(6); n <- 1000L
df <- data.frame(i = 1:n, d = rnorm(n), s = sample(c("a", "b", NA), n, TRUE),
  f = factor(sample(c("lo", "mid", "hi"), n, TRUE), levels = c("lo", "mid", "hi")),
  o = factor(sample(c("lo", "mid", "hi"), n, TRUE), levels = c("lo", "mid", "hi"), ordered = TRUE),
  dt = as.Date("2024-01-01") + 0:(n - 1), ts = as.POSIXct("2024-01-01 12:00", tz = "America/New_York") + 0:(n - 1),
  lg = sample(c(TRUE, FALSE, NA), n, TRUE), stringsAsFactors = FALSE)
attr(df$d, "label") <- "a labelled column"
attr(df, "my_attr") <- "custom table attribute"
rownames(df) <- paste0("r", seq_len(n))
tb <- tibble::as_tibble(df)
lc <- tibble::tibble(id = 1:5, l = list(1:3, c(1.5, 2), "x", NULL, list(a = 1)))
gr <- dplyr::group_by(tb, f)
dtd <- tibble::tibble(dur = as.difftime(1:5, units = "mins"), cplx = complex(real = 1:5, imaginary = 1), raw = as.raw(1:5))
s4 <- {setClass("Fid", representation(x = "numeric")); new("Fid", x = 1:3 + 0.5)}
objs <- list(df_rownames_attrs = df, tibble = tb, list_col = lc, grouped_df = gr, difftime_cplx_raw = dtd,
  named_list = list(a = 1, b = "z", c = list(d = 1:3)), s4_object = s4, formula = y ~ x, closure = function(x) x + 1,
  environment = list2env(list(a = 1)))
fmts <- list(
  rds = list(w = \(x, p) saveRDS(x, p), r = readRDS),
  qs2 = list(w = \(x, p) qs2::qs_save(x, p), r = qs2::qs_read),
  qd = list(w = \(x, p) qs2::qd_save(x, p, warn_unsupported_types = FALSE), r = qs2::qd_read),
  zap = list(w = \(x, p) zap::zap_write(x, p), r = \(p) zap::zap_read(p)),
  nanoparquet = list(w = \(x, p) nanoparquet::write_parquet(x, p), r = nanoparquet::read_parquet),
  arrow = list(w = \(x, p) arrow::write_parquet(x, p), r = arrow::read_parquet),
  duckdb = list(w = \(x, p) duck_write(x, p), r = duck_read))
if (!"zap" %in% STORAGE_PKGS) fmts$zap <- NULL
rows <- list()
for (on in names(objs)) for (fn in names(fmts)) {
  p <- file.path(SCRATCH, "fid.bin"); x <- objs[[on]]
  res <- tryCatch({ fmts[[fn]]$w(x, p); fmts[[fn]]$r(p) }, error = \(e) e, warning = \(w) w)
  status <- detail <- NA
  if (inherits(res, "condition")) { status <- if (inherits(res, "error")) "ERROR" else "WARN"; detail <- substr(gsub("[\r\n,]+", " ", conditionMessage(res)), 1, 100)
    if (status == "WARN") res <- tryCatch(suppressWarnings({ fmts[[fn]]$w(x, p); fmts[[fn]]$r(p) }), error = \(e) NULL) }
  if (!inherits(res, "error") && !(status %in% "ERROR")) {
    if (isTRUE(identical(x, res))) { status <- if (is.na(status)) "identical" else paste0(status, "+identical") }
    else {
      d <- character()
      if (!identical(class(x), class(res))) d <- c(d, paste0("class:", paste(class(x), collapse = "/"), "->", paste(class(res), collapse = "/")))
      if (is.data.frame(x) && is.data.frame(res)) {
        if (!identical(rownames(x), rownames(res))) d <- c(d, "row.names")
        for (cn in intersect(names(x), names(res))) if (!identical(x[[cn]], res[[cn]])) d <- c(d, paste0("col ", cn, ":", class(x[[cn]])[1], "->", class(res[[cn]])[1]))
        if (!identical(sort(setdiff(names(attributes(x)), c("names", "row.names", "class"))), sort(setdiff(names(attributes(res)), c("names", "row.names", "class"))))) d <- c(d, "table attrs")
        if (!identical(names(x), names(res))) d <- c(d, "names")
      } else if (is.null(res)) d <- c(d, "NULL returned") else if (!isTRUE(all.equal(x, res))) d <- c(d, "values/attrs differ")
      status <- paste0(if (is.na(status)) "" else paste0(status, "+"), "lossy"); detail <- paste(c(na.omit(detail), d), collapse = "; ")
    }
  }
  rows[[length(rows) + 1]] <- data.frame(topic = "storage", task = paste0("fidelity_", on), n = 1, method = fn, status = status, detail = detail)
}
fid <- do.call(rbind, rows); fid <- cbind(fid, bench_env())
for (i in seq_len(nrow(fid))) write_result(fid[i, ], "storage/results/fidelity.csv")
print(fid[, c("task", "method", "status", "detail")], right = FALSE, row.names = FALSE)

# ALTREP strings with qd_read, and first-touch cost
b <- make_b(2e5L, words = 115L)
p <- file.path(SCRATCH, "alt.qdata"); qs2::qd_save(b, p)
r_alt <- qs2::qd_read(p, use_alt_rep = TRUE); r_no <- qs2::qd_read(p, use_alt_rep = FALSE)
is_alt <- \(x) any(grepl("ALTREP|altrep|alt", capture.output(.Internal(inspect(x)))[1], ignore.case = TRUE))
message("qd_read text ALTREP (inspect line 1): ", capture.output(.Internal(inspect(r_alt$text)))[1])
message("use_alt_rep=FALSE (inspect line 1): ", capture.output(.Internal(inspect(r_no$text)))[1])
mk <- bench::mark(
  qd_alt_read = qs2::qd_read(p, use_alt_rep = TRUE),
  qd_noalt_read = qs2::qd_read(p, use_alt_rep = FALSE),
  qd_alt_read_then_touch = { r <- qs2::qd_read(p, use_alt_rep = TRUE); sum(nchar(r$text)) },
  qd_noalt_read_then_touch = { r <- qs2::qd_read(p, use_alt_rep = FALSE); sum(nchar(r$text)) },
  qd_alt_read_touch_1pct = { r <- qs2::qd_read(p, use_alt_rep = TRUE); sum(nchar(r$text[1:2000])) },
  iterations = ITER, check = FALSE, memory = FALSE)
tmp <- tempfile(); out <- record_mark(mk, "storage", "altrep_qd_b2e5", 2e5, tmp, STORAGE_PKGS, notes = "2e5-row version of b"); out$file_mb <- NA_real_; out$equal_ignoring_attrs <- NA
write_result(out, RES); print(out[, c("method", "median_s", "ratio_to_fastest")])
unlink(c(p, file.path(SCRATCH, "fid.bin")))
