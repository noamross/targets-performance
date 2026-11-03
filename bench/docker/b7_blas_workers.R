# Oversubscription: W mirai daemons each running BLAS-heavy tasks, on --cpus=6.
# Env: B7_VARIANT, B7_WORKERS (default 3), B7_RT ("none" | "blas<k>" | "omp<k>" | "both<k>": RhpcBLASctl call inside the task).
# Results: blas/results/blas_workers_linux.csv
source("_common.R"); suppressMessages(library(mirai))
variant <- Sys.getenv("B7_VARIANT"); W <- as.integer(Sys.getenv("B7_WORKERS", "3")); rt <- Sys.getenv("B7_RT", "none")
tenv <- paste0("OB=", Sys.getenv("OPENBLAS_NUM_THREADS", "-"), ",OMP=", Sys.getenv("OMP_NUM_THREADS", "-"))
task <- function(rt) {
  k <- suppressWarnings(as.integer(sub("\\D+", "", rt)))
  if (grepl("^(blas|both)", rt)) RhpcBLASctl::blas_set_num_threads(k)
  if (grepl("^(omp|both)", rt)) RhpcBLASctl::omp_set_num_threads(k)
  set.seed(1); A <- matrix(rnorm(1500^2), 1500); X <- cbind(1, matrix(rnorm(1e5 * 50), ncol = 50)); y <- rnorm(1e5)
  t0 <- Sys.time()
  for (i in 1:3) { crossprod(A); solve(crossprod(A) + diag(1500)); .lm.fit(X, y) }
  c(secs = as.numeric(Sys.time() - t0, units = "secs"), blas = RhpcBLASctl::blas_get_num_procs(), omp = RhpcBLASctl::omp_get_max_threads())
}
ntask <- 6
daemons(W); mirai_map(seq_len(W), \(i) Sys.getpid())[] 
t0 <- Sys.time()
res <- mirai_map(rep(rt, ntask), task)[]
wall <- as.numeric(Sys.time() - t0, units = "secs"); daemons(0)
r <- do.call(rbind, res)
cat(sprintf("%-8s %-18s W=%d rt=%-6s wall %6.2f s (6 tasks), per-task median %5.2f s, blas_procs %s omp %s\n", variant, tenv, W, rt, wall, median(r[, "secs"]), r[1, "blas"], r[1, "omp"]))
row <- data.frame(topic = "blas_workers", task = sprintf("W%d_rt_%s", W, rt), n = ntask, method = paste0(variant, "|", tenv), median_s = wall,
                  notes = sprintf("per_task_median_s=%.2f; blas_procs=%s; omp=%s", median(r[, "secs"]), r[1, "blas"], r[1, "omp"]))
write_result(cbind(row, bench_env()), "blas/results/blas_workers_linux.csv")
