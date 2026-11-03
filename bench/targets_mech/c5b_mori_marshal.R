# Case 5 add-on: marshal-based format (plain object stored, mori::share() only when shipped to a worker)
# vs format_qs_shared (duplicate on write, share on read) vs no mori (consumers in main) vs retrieval = "worker".
# Local copies of the formats add a log line per read/write/marshal/unmarshal call to $TM_LOG (ops R/W/M/U);
# the logic is otherwise identical to skills/targets-performance/scripts/formats.R.
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c5b_mori_marshal.csv"
rows <- list()
L <- function(op) sprintf("cat(sprintf('%s,%%d,%%.4f\\n', Sys.getpid(), proc.time()[[3]] - t0), file = Sys.getenv('TM_LOG'), append = TRUE)", op)
fmts <- paste0('
fmt_shared_log <- tar_format(
  read = function(path) { t0 <- proc.time()[[3]]; x <- mori::share(qs2::qs_read(path)); ', L("R"), '; x },
  write = function(object, path) { t0 <- proc.time()[[3]]; qs2::qs_save(rlang::duplicate(object), path); ', L("W"), ' })
fmt_marshal_log <- tar_format(
  read = function(path) { t0 <- proc.time()[[3]]; x <- qs2::qs_read(path); ', L("R"), '; x },
  write = function(object, path) { t0 <- proc.time()[[3]]; qs2::qs_save(object, path); ', L("W"), ' },
  marshal = function(object) { t0 <- proc.time()[[3]]; x <- mori::share(object); ', L("M"), '; x },
  unmarshal = function(object) { t0 <- proc.time()[[3]]; ', L("U"), '; object })
')
probe <- 'consume2 <- function(big, i) { spin(1); c(shared = mori::is_shared(big$x1), s = sum(big$x1) + sum(big$x2) * 0 + i) }'
mk <- function(kind, mb) {
  common <- c(sprintf("MB <- %d", mb), fmts, probe)
  big <- function(fmt, extra = "", cmd = "make_big(MB)") sprintf('tar_target(big, %s, format = %s, memory = "persistent", deployment = "main", storage = "main", retrieval = "main"%s)', cmd, fmt, extra)
  cons <- function(extra) sprintf('cons <- lapply(1:6, function(i) tar_target_raw(paste0("c", i), substitute(consume2(big, I), list(I = i)), format = "rds"%s))', extra)
  switch(kind,
    shared = paste(tm_prelude(NP3, memory = "persistent"), paste(common, collapse = "\n"), cons(', retrieval = "main"'), sprintf("c(list(%s), cons)", big("fmt_shared_log", cmd = "mori::share(make_big(MB))")), sep = "\n"),
    marshal = paste(tm_prelude(NP3, memory = "persistent"), paste(common, collapse = "\n"), cons(', retrieval = "main"'), sprintf("c(list(%s), cons)", big("fmt_marshal_log")), sep = "\n"),
    nomori_main_consumers = paste(tm_prelude(NP3, memory = "persistent"), paste(common, collapse = "\n"), cons(', deployment = "main", retrieval = "main"'), sprintf("c(list(%s), cons)", big("fmt_logged")), sep = "\n"),
    worker_retrieval = paste(tm_prelude(NP3, retrieval = "worker"), paste(common, collapse = "\n"), cons(""), 'c(list(tar_target(big, make_big(MB), format = fmt_logged)), cons)', sep = "\n"))
}
labs <- c(shared = "(e0) format_qs_shared, consumers retrieval main", marshal = "(e) marshal format (plain object; share on ship), retrieval main",
          nomori_main_consumers = "(f) no mori, persistent, consumers deployment main", worker_retrieval = "(g) retrieval worker, each consumer reads from disk")
after <- 'res$probe <- paste(vapply(1:6, function(i) { z <- tar_read_raw(paste0("c", i)); paste0(if (z[1] == 1) "S" else "-", "") }, ""), collapse = "")'
for (rep in 1:2) for (kind in names(labs)) {
  message("100 ", kind, " ", rep)
  if (!tm_fits(100 * (2 + 2 * NP3), "c5b 100 MB")) next
  r <- tm_run("c5b", mk(kind, 100), makes = 2, after = after)
  rows[[length(rows) + 1]] <- tm_row(sprintf("e_marshal_100MB_nproc%d", NP3), 100, sprintf("%s rep%d", labs[[kind]], rep), r, notes = sprintf("ops per make (R read, W write, M marshal, U unmarshal; one line per tar_make): %s; consumers saw shared (S) per consumer: %s; 2nd make completed=%d skipped=%d, wall %.2f s; errors=%d", r$ops, r$probe, r$completed[2], r$skipped[2], r$wall[2], r$errors))
}
for (kind in c("shared", "marshal", "nomori_main_consumers")) {
  message("300 ", kind)
  if (!tm_fits(300 * (2 + 2 * NP3), "c5b 300 MB")) next
  r <- tm_run("c5b", mk(kind, 300), makes = 2, after = after)
  rows[[length(rows) + 1]] <- tm_row(sprintf("e_marshal_300MB_nproc%d", NP3), 300, labs[[kind]], r, notes = sprintf("ops: %s; shared per consumer: %s; 2nd make completed=%d skipped=%d, wall %.2f s", r$ops, r$probe, r$completed[2], r$skipped[2], r$wall[2]))
}
# 3rd scenario: after the up-to-date make, invalidate the consumers and rebuild (read path of an up-to-date big)
for (kind in c("shared", "marshal")) {
  r <- tm_run("c5b", mk(kind, 100), makes = 2, between = "tar_invalidate(starts_with('c'))", after = after)
  rows[[length(rows) + 1]] <- tm_row("e_marshal_rebuild_consumers", 100, labs[[kind]], r, k = 2, notes = sprintf("ops per make: %s; shared per consumer (2nd make): %s; 2nd make completed=%d skipped=%d, wall %.2f s", r$ops, r$probe, r$completed[2], r$skipped[2], r$wall[2]))
}
tm_save(do.call(rbind, rows), OUT)
