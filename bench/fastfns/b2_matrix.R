source("fastfns/_ff.R")
suppressMessages({library(collapse)})
set_collapse(nthreads = 1)
PK <- c("base", "Rfast", "collapse", "kit")
nv <- function(r) unname(as.numeric(r))
for (n in c(1e3, 1e5, 1e7)) {
  nc <- if (n == 1e3) 10L else 100L; nr <- n / nc
  set.seed(2); m <- matrix(rnorm(n), nr, nc)
  mi <- if (n >= 1e7) 5 else 20
  cat("\n#####", n, nr, "x", nc, "\n")
  B <- function(task, e) bm(e, n, paste0("matrix_", task), "b2_matrix.csv", PK, norm = nv, max_it = mi, tol = 1e-8)
  B("rowSums", list(base = quote(rowSums(m)), Rfast = quote(Rfast::rowsums(m)), collapse_t = quote(fsum(t(m))), kit_psum = quote(do.call(kit::psum, asplit(m, 2)))))
  B("rowMeans", list(base = quote(rowMeans(m)), Rfast = quote(Rfast::rowmeans(m)), collapse_t = quote(fmean(t(m)))))
  B("colSums", list(base = quote(colSums(m)), Rfast = quote(Rfast::colsums(m)), collapse = quote(fsum(m))))
  B("colMeans", list(base = quote(colMeans(m)), Rfast = quote(Rfast::colmeans(m)), collapse = quote(fmean(m))))
  B("colVar", list(base_apply = quote(apply(m, 2, var)), Rfast = quote(Rfast::colVars(m)), collapse = quote(fvar(m))))
  B("rowVar", list(base_apply = quote(apply(m, 1, var)), Rfast = quote(Rfast::rowVars(m)), collapse_t = quote(fvar(t(m)))))
  B("colMedian", list(base_apply = quote(apply(m, 2, median)), Rfast = quote(Rfast::colMedians(m)), collapse = quote(fmedian(m))))
  B("rowMedian", list(base_apply = quote(apply(m, 1, median)), Rfast = quote(Rfast::rowMedians(m)), collapse_t = quote(fmedian(t(m)))))
  if (n <= 1e5) { # with NA
    m2 <- m; m2[sample(length(m2), length(m2) %/% 100)] <- NA
    m <- m2
    B("colMeans_NA", list(base = quote(colMeans(m, na.rm = TRUE)), collapse = quote(fmean(m)), Rfast_nonNA_unsafe = quote(Rfast::colmeans(m))))
  }
  rm(m); invisible(gc())
}
