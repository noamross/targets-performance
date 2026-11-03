# Helpers for fastfns benchmarks. Source after _common.R.
suppressMessages(source("_common.R"))
RES <- "fastfns/results"
TOPIC <- "fastfns"

# canonical (key, value) form for comparing grouped outputs
canon <- function(r) {
  if (is.data.frame(r)) { k <- r[[1]]; v <- r[[ncol(r)]] }
  else if (is.matrix(r) && !is.null(rownames(r))) { k <- rownames(r); v <- r[, 1] }
  else if (!is.null(names(r))) { k <- names(r); v <- unname(r) }
  else { k <- seq_along(r); v <- r }
  k <- as.character(k); o <- order(k, method = "radix")
  list(k = k[o], v = as.numeric(v)[o])
}

# exprs: named list of quoted calls. Evaluates each once for identity vs the first,
# times the ones that run, records via record_mark.
bm <- function(exprs, n, task, file, pkgs, norm = identity, env = parent.frame(),
               max_it = 10, notes = "", tol = 1e-9) {
  outs <- lapply(exprs, function(e) tryCatch(norm(eval(e, env)), error = function(err) structure(conditionMessage(err), class = "bm_err")))
  ok <- !vapply(outs, inherits, NA, "bm_err")
  if (!ok[1]) stop("reference failed: ", outs[[1]])
  ref <- outs[[1]]
  same <- vapply(seq_along(outs), function(i) ok[i] && identical(ref, outs[[i]]), NA)
  aeq <- vapply(seq_along(outs), function(i) ok[i] && isTRUE(all.equal(ref, outs[[i]], tolerance = tol, check.attributes = FALSE)), NA)
  names(same) <- names(aeq) <- names(exprs)
  if (any(!ok)) message("FAILED: ", paste(names(exprs)[!ok], vapply(outs[!ok], as.character, ""), collapse = " | "))
  rm(outs); invisible(gc())
  mark <- bench::mark(exprs = exprs[ok], min_iterations = 3, max_iterations = max_it, check = FALSE, memory = TRUE)
  nt <- paste0(notes, ifelse(aeq[as.character(mark$expression)], "; all.equal=TRUE", "; all.equal=FALSE"))
  names(nt) <- as.character(mark$expression)
  res <- record_mark(mark, TOPIC, task, n, file.path(RES, file), pkgs, same = same, notes = "")
  # attach per-row notes
  f <- file.path(RES, file); d <- read.csv(f, stringsAsFactors = FALSE)
  k <- d$task == task & d$n == n & d$method %in% names(nt)
  d$notes[k] <- nt[d$method[k]]
  write.csv(d, f, row.names = FALSE)
  cat(sprintf("%s n=%g\n", task, n)); print(res[order(res$median_s), c("method", "median_s", "ratio_to_fastest", "identical_to_ref")], row.names = FALSE)
  invisible(res)
}
