source("vectorize/_h.R")
f <- "vectorize/results/b3_elementwise.csv"
pk <- c("purrr", "collapse", "Rfast", "data.table", "kit", "vctrs")
nm <- function(x) as.numeric(unname(x))
set.seed(3)
scalar_f <- function(v) if (v > 0.5) v * 2 else v + 1
for (n in c(1e3, 1e5, 1e6)) {
  x <- runif(n)
  bm("scalar op over vector", n, f, pk, norm = nm,
     sapply = sapply(x, scalar_f), vapply = vapply(x, scalar_f, 0), map_dbl = purrr::map_dbl(x, scalar_f),
     lapply_unlist = unlist(lapply(x, scalar_f)), vectorized = ifelse(x > 0.5, x * 2, x + 1),
     vec_fifelse = data.table::fifelse(x > 0.5, x * 2, x + 1), vec_arith = x * ifelse(x > 0.5, 2, 1) + (x <= 0.5),
     max_iter = 10, min_time = 0.3)
  bm("sqrt over vector", n, f, pk, norm = nm, lapply_unlist = unlist(lapply(x, sqrt)), map_dbl = purrr::map_dbl(x, sqrt), vectorized = sqrt(x))
}
for (nr in c(1e3, 1e5, 1e6)) {
  m <- matrix(runif(nr * 10), nr, 10); task <- "row mean/sum of 10-col matrix"
  bm(task, nr, f, pk, norm = function(z) round(as.numeric(unname(z)), 10),
     apply_mean = apply(m, 1, mean), apply_sum_div = apply(m, 1, sum) / 10, rowMeans = rowMeans(m),
     Rfast_rowmeans = Rfast::rowmeans(m), collapse_fmean_t = collapse::fmean(t(m)),
     reduce_plus = Reduce(`+`, asplit(m, 2)) / 10, max_iter = 15, min_time = 0.3)
  bm("row var of 10-col matrix", nr, f, pk, norm = function(z) round(as.numeric(unname(z)), 8),
     apply_var = apply(m, 1, var), Rfast_rowVars = Rfast::rowVars(m), vector_formula = (rowSums(m^2) - rowSums(m)^2 / 10) / 9, max_iter = 10, min_time = 0.3)
}
