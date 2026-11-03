source("vectorize/_h.R")
library(data.table)
f <- "vectorize/results/b7_join_cbind.csv"
pk <- c("data.table", "dplyr", "collapse", "vctrs")
set.seed(8)
nm <- function(d) { d <- as.data.frame(d); d <- d[order(d$id), c("id", paste0("v", seq_len(ncol(d) - 1)))]; rownames(d) <- NULL; d }
for (cs in list(c(5, 1e3), c(5, 1e5), c(20, 1e4), c(100, 1e3), c(100, 1e4))) {
  k <- cs[1]; n <- cs[2]; if (!fits_or_skip(k * n * 16 / 2^20, 10, sprintf("b7 k=%g n=%g", k, n))) next
  ids <- sample(n)
  l <- lapply(seq_len(k), \(j) { d <- data.frame(id = ids, v = runif(n)); names(d)[2] <- paste0("v", j); d })
  task <- sprintf("combine %d tables x %g keys", k, n)
  ex <- list(
    reduce_merge = quote(Reduce(\(a, b) merge(a, b, by = "id"), l)),
    reduce_left_join = quote(Reduce(\(a, b) dplyr::left_join(a, b, by = "id"), l)),
    reduce_dt_merge = quote(Reduce(\(a, b) merge(a, b, by = "id"), lapply(l, as.data.table))),
    stack_dcast = quote({ s <- rbindlist(lapply(l, \(d) data.table(id = d$id, nm = names(d)[2], val = d[[2]]))); dcast(s, id ~ nm, value.var = "val")[, c("id", paste0("v", seq_len(.N_k))), with = FALSE] }),
    collapse_join = quote(Reduce(\(a, b) collapse::join(a, b, on = "id", verbose = 0), l)),
    cbind_cols = quote(cbind(l[[1]], do.call(cbind, lapply(l[-1], `[`, 2)))),
    unlist_cols = quote(data.frame(id = ids, unlist(lapply(l, `[`, 2), recursive = FALSE))),
    vec_cbind = quote(rlang::inject(vctrs::vec_cbind(l[[1]], !!!lapply(l[-1], `[`, 2)))),
    collapse_add_vars = quote(collapse::add_vars(l[[1]], collapse::get_vars(collapse::rowbind(l[-1], idcol = FALSE)[0, ], 1)))
  )
  ex$collapse_add_vars <- NULL
  ex$stack_dcast <- eval(bquote(quote({ s <- rbindlist(lapply(l, \(d) data.table(id = d$id, nm = names(d)[2], val = d[[2]]))); dcast(s, id ~ nm, value.var = "val")[, c("id", paste0("v", seq_len(.(k)))), with = FALSE] })))
  if (k * n > 1e6 || k >= 100) ex$reduce_merge <- if (k >= 100 && n >= 1e4) NULL else ex$reduce_merge
  do.call(bm, c(list(task = task, n = k * n, file = f, pkgs = pk, norm = nm, max_iter = 5, min_time = 0, notes = sprintf("k=%d tables, %g keys; keys in same order for cbind variants", k, n)), ex))
}
