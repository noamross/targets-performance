source("vectorize/_h.R")
library(data.table)
f <- "vectorize/results/b4_pairs.csv"; pk <- c("data.table", "kit")
set.seed(4); dt0 <- getDTthreads(); T4 <- min(4L, bench_cores())
if (T4 < 2) message("skipping multi-thread rows: 1 core")
for (n in c(1e5, 1e6)) {
  a <- runif(n); b <- runif(n); nm <- function(x) as.numeric(unname(x))
  setDTthreads(1)
  bm("pairwise min", n, f, pk, norm = nm, fifelse_1thread = fifelse(a < b, a, b), kit_iif_1thread = kit::iif(a < b, a, b, nThread = 1),
     notes = "DTthreads=1; kit nThread=1")
  setDTthreads(dt0)
  if (T4 >= 2) do.call(bm, setNames(list("pairwise min", n, f, pk, norm = nm, quote(kit::iif(a < b, a, b, nThread = T4)),
    notes = sprintf("kit nThread=%d (data.table default threads %d)", T4, dt0)), c("", "", "", "", "norm", sprintf("kit_iif_%dthreads", T4), "notes")))
}
