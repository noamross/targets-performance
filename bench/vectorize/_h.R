source("_common.R")
# bm(): run named expressions with bench::mark, check identical() vs first, record.
bm <- function(task, n, file, pkgs, ..., notes = "", norm = identity, min_time = 0.5, max_iter = 30) {
  exprs <- rlang::exprs(...)
  env <- parent.frame()
  outs <- lapply(exprs, function(e) tryCatch(norm(eval(e, env)), error = function(err) structure(list(conditionMessage(err)), class = "bm_err")))
  same <- vapply(outs, function(o) identical(outs[[1]], o), logical(1))
  m <- bench::mark(exprs = exprs, env = env, check = FALSE, min_iterations = 3, max_iterations = max_iter, min_time = min_time, memory = TRUE, filter_gc = FALSE)
  r <- record_mark(m, "vectorize", task, n, file, pkgs, same = same, notes = notes)
  print(r[, c("task", "n", "method", "median_s", "ratio_to_fastest", "identical_to_ref")], row.names = FALSE)
  invisible(r)
}
