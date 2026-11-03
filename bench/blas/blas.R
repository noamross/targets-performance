# Linear algebra speed under the BLAS that R is currently linked to.
# Run once per BLAS variant (switch it between runs; see references/environment.md), from bench/:
#   Rscript run_capped.R blas/blas.R 3
# Saves results/blas.csv (times), results/blas_<blas>.rds (outputs, gitignored) and
# results/blas_diffs.csv (how far outputs differ from other variants run here).
source("_common.R")
blas <- if (grepl("vecLib|Accelerate", sessionInfo()$BLAS)) "accelerate" else basename(sessionInfo()$BLAS)
set.seed(1)
n <- 2000
check_fits(n^2 * 8 / 2^20, copies = 8, "blas matrices")
A <- matrix(rnorm(n^2), n)
S <- crossprod(A) + diag(n)
X <- cbind(1, matrix(rnorm(2e5 * 50), ncol = 50))
y <- drop(X %*% rnorm(51)) + rnorm(2e5)
ops <- list(
  crossprod = function() crossprod(A),
  matmul = function() A %*% A,
  solve = function() solve(S),
  chol = function() chol(S),
  svd_1000 = function() svd(A[1:1000, 1:1000]),
  qr = function() qr(A),
  lm_fit_2e5x51 = function() .lm.fit(X, y)$coefficients,
  glm_logit_2e5x51 = function() stats::glm.fit(X, as.numeric(y > 0), family = binomial())$coefficients
)
outs <- list()
for (op in names(ops)) {
  m <- bench::mark(outs[[op]] <- ops[[op]](), min_iterations = 3, check = FALSE)
  rows <- data.frame(topic = "blas", task = op, n = n, method = blas, median_s = as.numeric(m$median),
                     ratio_to_fastest = NA, mem_alloc_mb = as.numeric(m$mem_alloc) / 2^20, n_itr = m$n_itr,
                     identical_to_ref = NA, notes = sessionInfo()$BLAS, packages = "")
  write_result(cbind(rows, bench_env()), "blas/results/blas.csv")
  cat(sprintf("%-18s %-11s %8.3f s\n", op, blas, as.numeric(m$median)))
}
if (nzchar(Sys.getenv("CI"))) quit(save = "no") # one BLAS per CI runner: no diffs; outputs too big to store
saveRDS(outs, sprintf("blas/results/blas_%s.rds", blas))
# Outputs (.rds, large, gitignored) stay local; the cross-BLAS differences go to blas_diffs.csv.
num_of <- function(z) if (is.list(z)) unlist(z[vapply(z, is.numeric, TRUE)]) else as.numeric(z)
other <- setdiff(list.files("blas/results", "^blas_.*\\.rds$", full.names = TRUE), sprintf("blas/results/blas_%s.rds", blas))
for (f in other) {
  ref <- readRDS(f)
  ops <- intersect(names(ref), names(outs))
  # Largest absolute difference ignoring sign (factorizations may flip it), relative to the largest value
  diffs <- vapply(ops, \(o) { a <- num_of(outs[[o]]); r <- num_of(ref[[o]]); max(abs(abs(a) - abs(r))) / max(abs(r)) }, 0)
  d <- data.frame(topic = "blas", task = ops, n = NA, method = blas, ref_method = sub("^blas_(.*)\\.rds$", "\\1", basename(f)),
                  max_rel_diff = unname(diffs), identical = vapply(ops, \(o) identical(outs[[o]], ref[[o]]), TRUE))
  write_result(cbind(d, bench_env()), "blas/results/blas_diffs.csv")
  print(d[, c("task", "ref_method", "max_rel_diff", "identical")], row.names = FALSE)
}
