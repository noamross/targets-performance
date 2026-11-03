source("vectorize/_h.R")
f <- "vectorize/results/b1_rbind.csv"
pk <- c("data.table", "collapse")
set.seed(1)
mk <- function(n_df, nr) lapply(seq_len(n_df), function(i) data.frame(id = seq_len(nr) + i, x = runif(nr), g = sample(letters, nr, TRUE)))
dt0 <- data.table::getDTthreads(); cl0 <- collapse::get_collapse()$nthreads
cat("default threads: data.table", dt0, "collapse", cl0, "\n")
for (cs in list(list(1e3, 10), list(100, 1e3), list(5, 1e6))) {
  l <- mk(cs[[1]], cs[[2]]); task <- sprintf("rbind %g dfs x %g rows", cs[[1]], cs[[2]])
  norm <- function(d) { d <- as.data.frame(d); rownames(d) <- NULL; d }
  data.table::setDTthreads(1); collapse::set_collapse(nthreads = 1)
  bm(task, cs[[1]] * cs[[2]], f, pk, rbindlist_1thread = as.data.frame(data.table::rbindlist(l)),
     collapse_rowbind_1thread = as.data.frame(collapse::rowbind(l)), norm = norm,
     notes = sprintf("DTthreads=1 collapse nthreads=1 (defaults %d/%d)", dt0, cl0))
  data.table::setDTthreads(dt0); collapse::set_collapse(nthreads = cl0)
}
