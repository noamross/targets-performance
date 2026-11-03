# Oversubscription: W mirai daemons each run a multithreaded data.table task.
# Run: cd bench && Rscript startup/oversubscribe.R
library(mirai)
source("_common.R")
ncpu <- bench_cores()
W <- max(1L, ncpu %/% 2)
task <- function(threads) {
  library(data.table)
  if (!is.null(threads)) setDTthreads(threads)
  set.seed(1); n <- 2e6
  DT <- data.table(g = sample.int(2e5, n, TRUE), x = runif(n))
  t <- system.time({ for (i in 1:10) r <- DT[, .(s = sum(x), m = mean(x)), by = g]; setorder(DT, g, x) })[["elapsed"]]
  c(threads = getDTthreads(), elapsed = t)
}
run <- function(threads, W) {
  daemons(W); on.exit(daemons(0))
  everywhere({}) 
  t0 <- Sys.time()
  m <- mirai_map(rep(list(threads), W), task)[]
  c(wall = as.numeric(difftime(Sys.time(), t0, units = "secs")), threads = m[[1]][["threads"]])
}
res <- rbind(
  data.frame(setting = "default (50% each)", t(run(NULL, W))),
  data.frame(setting = "1 thread each", t(run(1, W))),
  data.frame(setting = "all cpus each", t(run(ncpu, W))))
res$workers <- W; res$ncpu <- ncpu; res$date <- as.character(Sys.Date())
print(res); write.csv(res, "startup/results/oversubscribe.csv", row.names = FALSE)
