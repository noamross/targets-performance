# Linux container variant of fastfns/b6_threads.R (+ qs2). Run via docker/run.sh from bench/.
source("fastfns/_ff.R")
suppressMessages({library(data.table); library(collapse); library(kit); library(qs2)})
PK <- c("data.table", "collapse", "kit", "Rfast", "qs2")
OUT <- "b6_threads_linux.csv"
THREADS <- c(1, 2, 4, 6)
n <- 1e7; check_fits(n * 8 / 2^20, 8, "threads")
set.seed(6)
g <- sample.int(1e3, n, TRUE); x <- rnorm(n); xi <- sample.int(1e6, n, TRUE)
m <- matrix(x, 1e5, 100); dt <- data.table(g = g, x = x); cond <- x > 0
tf <- "/scratch/b7_qs2.qs2"
qs_save(x, tf, nthreads = 1)
tt <- function(task, mk) {
  e <- list(); for (k in THREADS) e[[paste0("threads_", k)]] <- mk(k)
  bm(e, n, task, OUT, PK, norm = function(r) if (is.data.frame(r)) as.numeric(r[[ncol(r)]]) else as.numeric(r), max_it = 8)
}
tt("DT_groupby_sum", \(k) bquote({setDTthreads(.(k)); dt[, .(v = sum(x)), by = g]}))
tt("DT_forder_dbl", \(k) bquote({setDTthreads(.(k)); data.table:::forder(x)}))
tt("DT_forder_int", \(k) bquote({setDTthreads(.(k)); data.table:::forder(xi)}))
tt("DT_uniqueN_int", \(k) bquote({setDTthreads(.(k)); uniqueN(xi)}))
setDTthreads(1)
tt("collapse_fsum_matrix_cols", \(k) bquote(fsum(m, nthreads = .(k))))
tt("collapse_fsum_grouped_vec", \(k) bquote(fsum(x, g, nthreads = .(k))))
tt("collapse_fmedian_grouped", \(k) bquote(fmedian(x, g, nthreads = .(k))))
tt("collapse_fnth90_grouped", \(k) bquote(fnth(x, 0.9, g, nthreads = .(k))))
tt("kit_iif", \(k) bquote(iif(cond, 1, -1, nThread = .(k))))
tt("kit_psort_dbl", \(k) bquote(psort(x, nThread = .(k))))
tt("Rfast_colMedians", \(k) bquote(Rfast::colMedians(m, parallel = .(k > 1), cores = .(k))))
tt("Rfast_colVars", \(k) bquote(Rfast::colVars(m, parallel = .(k > 1), cores = .(k))))
tt("qs2_save_dbl", \(k) bquote(qs_save(x, "/scratch/b7_w.qs2", nthreads = .(k))))
tt("qs2_read_dbl", \(k) bquote(qs_read(tf, nthreads = .(k))))
unlink(c(tf, "/scratch/b7_w.qs2"))
