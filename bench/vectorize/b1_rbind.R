source("vectorize/_h.R")
f <- "vectorize/results/b1_rbind.csv"
pk <- c("data.table", "vctrs", "purrr", "collapse", "dplyr")
mk <- function(n_df, nr) lapply(seq_len(n_df), function(i) data.frame(id = seq_len(nr) + i, x = runif(nr), g = sample(letters, nr, TRUE)))
set.seed(1)
cases <- list(list(1e2, 10), list(1e3, 10), list(1e4, 10), list(1e2, 1e3), list(10, 1e5), list(5, 1e6))
for (cs in cases) {
  l <- mk(cs[[1]], cs[[2]]); tot <- cs[[1]] * cs[[2]]
  task <- sprintf("rbind %g dfs x %g rows", cs[[1]], cs[[2]])
  ex <- list(
    do_call_rbind = quote(do.call(rbind, l)),
    list_rbind = quote(purrr::list_rbind(l)),
    vec_rbind = quote(vctrs::vec_rbind(!!!l)),
    rbindlist = quote(as.data.frame(data.table::rbindlist(l))),
    collapse_rowbind = quote(as.data.frame(collapse::unlist2d(l, idcols = FALSE))),
    collapse_rbind = quote(as.data.frame(collapse::rowbind(l)))
  )
  if (cs[[1]] >= 1e4) ex$do_call_rbind <- if (cs[[1]] >= 1e4) ex$do_call_rbind
  ex$vec_rbind <- quote(vctrs::vec_rbind(!!!l))
  ex$Reduce_rbind <- quote(Reduce(rbind, l))
  if (cs[[1]] > 1e3) ex$Reduce_rbind <- NULL
  ex$vec_rbind <- NULL; ex$vec_rbind <- quote(rlang::inject(vctrs::vec_rbind(!!!l)))
  args <- c(list(task = task, n = tot, file = f, pkgs = pk, norm = function(d) { d <- as.data.frame(d); rownames(d) <- NULL; d }), ex)
  do.call(bm, args)
}
