# BLAS (pthread vs openmp OpenBLAS) mixed with data.table OpenMP, same process, then after fork.
# Env: B7_VARIANT. Results: blas/results/blas_dt_linux.csv
source("_common.R"); suppressMessages(library(data.table))
variant <- Sys.getenv("B7_VARIANT"); tenv <- paste0("OB=", Sys.getenv("OPENBLAS_NUM_THREADS", "-"), ",OMP=", Sys.getenv("OMP_NUM_THREADS", "-"))
setDTthreads(6)
set.seed(1); xi <- sample.int(1e6, 1e7, TRUE); A <- matrix(rnorm(1500^2), 1500)
dtop <- function() uniqueN(xi); blop <- function() crossprod(A)
tm <- function(f, k = 5) { f(); median(vapply(seq_len(k), \(i) system.time(f())[["elapsed"]], 0)) }
rows <- list(); add <- function(task, s, note = "") rows[[length(rows) + 1]] <<- data.frame(topic = "blas_dt", task = task, n = 1500, method = paste0(variant, "|", tenv), median_s = s, notes = note)
add("dt_alone", tm(dtop)); add("blas_alone", tm(blop))
inter <- function() { dtop(); blop() }; add("dt_plus_blas_sequential", tm(inter))
sumalone <- rows[[1]]$median_s + rows[[2]]$median_s
cat(sprintf("%-8s %-22s dt %.3f blas %.3f both %.3f (sum alone %.3f)\n", variant, tenv, rows[[1]]$median_s, rows[[2]]$median_s, rows[[3]]$median_s, sumalone))
# after fork: child runs BLAS and DT after parent used both pools
jobs <- lapply(1:2, \(i) parallel::mcparallel({ r <- system.time(blop())[["elapsed"]]; r2 <- system.time(dtop())[["elapsed"]]; c(r, r2) }))
res <- parallel::mccollect(jobs, wait = FALSE, timeout = 90)
ok <- !is.null(res) && all(vapply(res, is.numeric, NA))
cat(sprintf("  fork children (2): %s\n", if (ok) paste(sprintf("blas %.3f dt %.3f", sapply(res, `[`, 1), sapply(res, `[`, 2)), collapse = " | ") else "HUNG or failed (90 s)"))
add("fork_children_blas_s", if (ok) mean(sapply(res, `[`, 1)) else NA_real_, if (ok) "ok" else "hung")
if (!ok) tools::pskill(vapply(jobs, `[[`, 0L, "pid"), tools::SIGKILL)
write_result(cbind(do.call(rbind, rows), bench_env()), "blas/results/blas_dt_linux.csv")
