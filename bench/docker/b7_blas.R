# Linux variant of blas/blas.R. Env: B7_VARIANT (label). Run from bench/ via docker/run.sh.
# Appends to blas/results/blas_linux.csv; method = "<variant>|<thread env>".
source("_common.R")
variant <- Sys.getenv("B7_VARIANT", "unknown")
tenv <- paste0(sprintf("OPENBLAS_NUM_THREADS=%s", Sys.getenv("OPENBLAS_NUM_THREADS", "-")),
               ",", sprintf("OMP_NUM_THREADS=%s", Sys.getenv("OMP_NUM_THREADS", "-")))
maps <- readLines("/proc/self/maps"); lib <- paste(unique(basename(sub(".* ", "", grep("openblas|libblas|libgomp", maps, value = TRUE)))), collapse = "+")
set.seed(1); n <- 2000
check_fits(n^2 * 8 / 2^20, copies = 8, "blas matrices")
A <- matrix(rnorm(n^2), n); S <- crossprod(A) + diag(n)
X <- cbind(1, matrix(rnorm(2e5 * 50), ncol = 50)); y <- drop(X %*% rnorm(51)) + rnorm(2e5)
ops <- list(
  crossprod = function() crossprod(A), matmul = function() A %*% A, solve = function() solve(S),
  chol = function() chol(S), svd_1000 = function() svd(A[1:1000, 1:1000]), qr = function() qr(A),
  lm_fit_2e5x51 = function() .lm.fit(X, y)$coefficients,
  glm_logit_2e5x51 = function() stats::glm.fit(X, as.numeric(y > 0), family = binomial())$coefficients)
blas_threads <- RhpcBLASctl::blas_get_num_procs(); omp_threads <- RhpcBLASctl::omp_get_max_threads()
outs <- list()
for (op in names(ops)) {
  m <- bench::mark(outs[[op]] <- ops[[op]](), min_iterations = 3, max_iterations = 15, check = FALSE)
  rows <- data.frame(topic = "blas", task = op, n = n, method = paste0(variant, "|", tenv), median_s = as.numeric(m$median),
                     ratio_to_fastest = NA, mem_alloc_mb = as.numeric(m$mem_alloc) / 2^20, n_itr = m$n_itr,
                     identical_to_ref = NA, notes = sprintf("%s; blas_threads=%s omp_max=%s", lib, blas_threads, omp_threads), packages = "")
  write_result(cbind(rows, bench_env()), "blas/results/blas_linux.csv")
  cat(sprintf("%-10s %-34s %-18s %8.3f s\n", variant, tenv, op, as.numeric(m$median)))
}
ref <- "/scratch/b7_blas_reference.rds"
if (variant == "reference" && !file.exists(ref)) saveRDS(outs, ref)
if (file.exists(ref) && variant != "reference") {
  r <- readRDS(ref)
  d <- vapply(names(outs), function(op) { a <- unlist(r[[op]]); b <- unlist(outs[[op]]); max(abs(a - b) / pmax(abs(a), 1e-300)) }, 0)
  cat(sprintf("maxreldiff_vs_reference %s: %s\n", variant, paste(names(d), signif(d, 2), collapse = " ")))
}
