# Case 8: parallel level: one target with threads vs 6 branches x 1 thread vs 6 branches x threads (oversubscribed).
# Task: 6 data.table jobs (4e6 rows, 4e5 groups: grouped sum/mean + setorder, 6 times). Threads via env var
# R_DATATABLE_NUM_THREADS set in _targets.R before the crew controller starts (workers inherit it) and
# applied with setDTthreads() inside the job: targets itself loads data.table in the main process, so the
# env var alone is ignored there (verified: dt loaded before the target, 6 threads despite env=1).
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c8_level.csv"
rows <- list()
job <- 'job <- function(k) {
  library(data.table); setDTthreads(as.integer(Sys.getenv("R_DATATABLE_NUM_THREADS"))); set.seed(k); n <- 4e6
  DT <- data.table(g = sample.int(4e5, n, TRUE), x = runif(n))
  for (i in 1:6) r <- DT[, .(s = sum(x), m = mean(x), mx = max(x)), by = g]
  setorder(DT, g, x)
  c(sum = sum(r$s), threads = getDTthreads())
}'
mk <- function(kind, thr) {
  pre <- tm_prelude(if (kind == "one") 1 else NP6, extra_opts = NULL)
  pre <- sub("library(targets)", sprintf("Sys.setenv(R_DATATABLE_NUM_THREADS = '%d', OMP_NUM_THREADS = '%d'); library(targets)", thr, thr), pre, fixed = TRUE)
  paste(pre, job, switch(kind,
    one = 'list(tar_target(res, lapply(1:6, job)))',
    branches = 'list(tar_target(k, 1:6), tar_target(res, job(k), pattern = map(k), iteration = "list"))'), sep = "\n")
}
W <- NP6
cfg <- list(list("one", W, sprintf("1 target, 6 jobs sequential, DT threads = %d", W)),
            list("one", 1, "1 target, 6 jobs sequential, DT threads = 1"),
            list("branches", 1, sprintf("6 branches x 1 thread, NPROC=%d", W)),
            list("branches", 2, sprintf("6 branches x 2 threads, NPROC=%d (=%d threads)", W, 2 * W)),
            list("branches", W, sprintf("6 branches x %d threads, NPROC=%d (%d threads, oversubscribed)", W, W, W * W)),
            list("branches", 2 * W, sprintf("6 branches x %d threads, NPROC=%d (%d threads)", 2 * W, W, 2 * W * W)))
# a small machine can make two configurations the same; drop repeats
cfg <- cfg[!duplicated(vapply(cfg, \(z) paste(z[[1]], z[[2]]), ""))]
for (rep in 1:2) for (cc in cfg) {
  r <- tm_run("c8", mk(cc[[1]], cc[[2]]), after = "res$thr <- tryCatch(paste(unique(unlist(lapply(tar_read(res), function(z) if (is.list(z)) z[[1]]['threads'] else z['threads']))), collapse = ','), error = function(e) NA)")
  rows[[length(rows) + 1]] <- tm_row("dt_6jobs", cc[[2]], sprintf("%s rep%d", cc[[3]], rep), r, notes = sprintf("threads seen in jobs: %s", r$thr))
}
tm_save(do.call(rbind, rows), OUT)
