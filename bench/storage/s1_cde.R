source("storage/_storage.R")
core <- c("rds_gzip", "rds_none", "qs2_t1", "qs2_t4", "qs2_t1_l1", "qs2_t4_l1", "qd_t1", "qd_t4", "zap")
pq <- c("np_zstd", "arrow_zstd", "duck_zstd", "fst")

# (c) nested list of 1e5 small data frames, and list-column tibble
set.seed(3)
lst <- lapply(1:1e5, \(i) data.frame(a = sample.int(100L, 10), b = rnorm(10), c = sample(letters, 10, TRUE)))
message("c list: ", format(object.size(lst), units = "MB"))
bench_object(lst, "c_listdf", core, 1e5, notes = "list of 1e5 data.frames (10x3)")
lc <- tibble(id = 1:1e5, data = lst)
bench_object(lc, "c_listcol", c(core, pq), 1e5, notes = "tibble with list-column of 1e5 data.frames")
rm(lst, lc); gc()

# (d) matrix 5000x5000
if (fits_or_skip(200, 6, "d_matrix")) {
set.seed(4); mat <- matrix(rnorm(25e6), 5000, 5000)
M_ALL$np_zstd_df <- list(w = \(x, p) nanoparquet::write_parquet(as.data.frame(x), p, compression = "zstd"),
  r = \(p) as.matrix(nanoparquet::read_parquet(p)), ext = "parquet")
M_ALL$arrow_zstd_df <- list(w = \(x, p) arrow::write_parquet(as.data.frame(x), p, compression = "zstd"),
  r = \(p) as.matrix(arrow::read_parquet(p)), ext = "parquet")
bench_object(mat, "d_matrix", c(core, "np_zstd_df", "arrow_zstd_df"), 25e6, notes = "5000x5000 dbl matrix; *_df rows include as.data.frame/as.matrix conversion")
rm(mat); gc()
}

# (e) fitted-model-like object with function + environment
make_e <- function(n = 5e5) {
  d <- data.frame(y = rnorm(n), x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  fit <- lm(y ~ x1 + x2 + x3, data = d)   # formula env = this function frame (holds d)
  e <- new.env(); e$cache <- rnorm(1e6); e$label <- "cache"
  fn <- local({ k <- 2; function(x) x * k })
  list(fit = fit, fn = fn, e = e)
}
set.seed(5); obj <- make_e()
chk <- function(x, res) {
  isTRUE(all.equal(coef(x$fit), coef(res$fit))) && is.function(res$fn) && isTRUE(res$fn(3) == 6) &&
    is.environment(res$e) && isTRUE(all.equal(res$e$cache, x$e$cache)) && inherits(res$fit, "lm")
}
M_ALL$qd_t1$w  # unchanged
bench_object(obj, "e_model", c("rds_gzip", "rds_none", "qs2_t1", "qs2_t4", "qd_t1", "zap", "np_zstd", "arrow_zstd"), 1,
  check = chk, notes = "list(lm fit, closure, environment); identical_to_ref = functional check (coef, closure, env contents), not identical()")
# What does each return?
for (m in c("qd_t1", "zap", "qs2_t1")) {
  p <- file.path(SCRATCH, paste0("e.", m)); w <- tryCatch(withCallingHandlers(M_ALL[[m]]$w(obj, p), warning = \(w) {message(m, " WARN: ", conditionMessage(w)); invokeRestart("muffleWarning")}), error = \(e) message(m, " ERR: ", conditionMessage(e)))
  r <- tryCatch(M_ALL[[m]]$r(p), error = \(e) { message(m, " READ ERR: ", conditionMessage(e)); NULL })
  if (!is.null(r)) message(m, ": classes = ", paste(names(r), vapply(r, \(z) class(z)[1], ""), sep = "=", collapse = ", "), "; fit$terms env: ", tryCatch(class(environment(r$fit$terms)), error = \(e) "NA"))
  unlink(p)
}
