# Case 6c: map over chunks vs over a target holding the big table (each branch gets the whole table).
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c6c_bigmap.csv"
MB <- 200; rows <- list()
RETR <- Sys.getenv("C6C_RETR", "auto")  # tm_prelude retrieval; old rows (worker) renamed "[retrieval=worker] ..."
pre <- function(np, ...) paste(tm_prelude(np, ...), 'part <- function(d) { spin(0.5); sum(d$x1) }
make_chunk <- function(i) { set.seed(i); n <- as.integer(%MB% * 1e6 / 8 / 10 / 6); as.data.frame(matrix(runif(n * 10), ncol = 10, dimnames = list(NULL, paste0("x", 1:10)))) }', sep = "\n")
pre <- function(np, ...) sub("%MB%", MB, pre0 <- paste(tm_prelude(np, ...), 'part <- function(d) { spin(0.5); sum(d$x1) }
make_chunk <- function(i) { set.seed(i); n <- as.integer(%MB% * 1e6 / 8 / 10 / 6); as.data.frame(matrix(runif(n * 10), ncol = 10, dimnames = list(NULL, paste0("x", 1:10)))) }', sep = "\n"), fixed = TRUE)
variants <- list(
  "A map over group-iterated big table target" = sprintf('list(tar_group_count(tbl, make_big(%d), count = 6, format = fmt_logged), tar_target(res, part(tbl), pattern = map(tbl), iteration = "list"))', MB),
  "B map over list-of-chunks target (one stored object)" = sprintf('list(tar_target(chunks, split(make_big(%d), rep(1:6, length.out = %d * 1e6 / 80)), iteration = "list", format = fmt_logged), tar_target(res, part(chunks), pattern = map(chunks), iteration = "list"))', MB, MB),
  "C branches use the whole table as static dependency" = sprintf('list(tar_target(tbl, make_big(%d), format = fmt_logged), tar_target(ids, 1:6), tar_target(res, { part(tbl[seq(ids, nrow(tbl), by = 6), ]) }, pattern = map(ids), iteration = "list"))', MB),
  "D chunks produced per branch (dynamic chunk target)" = 'list(tar_target(ids, 1:6), tar_target(chunks, make_chunk(ids), pattern = map(ids), format = fmt_logged, iteration = "list"), tar_target(res, part(chunks), pattern = map(chunks), iteration = "list"))')
for (v in names(variants)) for (np in c(1, NP3)) {
  message(v, " ", np)
  if (!tm_fits(MB * (2 + 2 * np), sprintf("c6c np %d", np))) next
  src <- paste(pre(np, retrieval = RETR), variants[[v]], sep = "\n")
  r <- tryCatch(tm_run("c6c", src, after = "res$by_name <- tapply(res$meta$seconds, sub('_[0-9a-f]+$', '', res$meta$name), sum)"), error = function(e) { message(conditionMessage(e)); NULL })
  if (!is.null(r)) rows[[length(rows) + 1]] <- tm_row("6branches_200MB", 6, sprintf("%s [retrieval=%s]: %s", if (np == 1) "serial" else sprintf("nproc=%d", np), RETR, v), r, notes = if (isTRUE(r$capped)) "" else paste(names(r$by_name), round(r$by_name, 2), collapse = "; "))
}
tm_save(do.call(rbind, rows), OUT)
