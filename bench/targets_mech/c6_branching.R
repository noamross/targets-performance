# Case 6: dynamic branching overhead: 1e4 rows as B branches (tar_group_count / manual chunk list) vs one target.
# Work is CPU-bound, 0.5 ms per row (5 s total). Then: map over chunks vs map over a target holding the big table.
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c6_branching.csv"
rows <- list(); add <- function(...) rows[[length(rows) + 1]] <<- tm_row(...)
N <- 1e4; MS_PER_ROW <- 0.0005
work <- 'proc <- function(d) { spin(nrow(d) * 0.0005); sum(d$x) }
tbl <- data.frame(id = 1:1e4, x = (1:1e4) / 1e4)'
src_b <- function(nproc, kind, B) paste(tm_prelude(nproc), work, switch(kind,
  group = sprintf('list(tar_group_count(grp, tbl, count = %d), tar_target(res, proc(grp), pattern = map(grp), iteration = "list"), tar_target(total, sum(unlist(res))))', B),
  list = sprintf('list(tar_target(chunks, split(tbl, rep_len(1:%d, nrow(tbl))), iteration = "list"), tar_target(res, proc(chunks), pattern = map(chunks), iteration = "list"), tar_target(total, sum(unlist(res))))', B),
  one = 'list(tar_target(res, proc(tbl)), tar_target(total, sum(res)))'), sep = "\n")
tot <- NULL
for (np in c(1, NP4)) {
  r <- tm_run("c6", src_b(np, "one", 1), after = "res$total <- tar_read(total)"); add("1e4rows_0.5ms", 1, sprintf("%s one target", if (np == 1) "serial" else sprintf("nproc=%d", np)), r, notes = "5 s CPU in one target")
  for (kind in c("list", "group")) for (B in c(10, 100, 1000)) {
    r <- tm_run("c6", src_b(np, kind, B), after = "res$total <- tar_read(total)")
    add("1e4rows_0.5ms", B, sprintf("%s %s B=%d", if (np == 1) "serial" else sprintf("nproc=%d", np), kind, B), r, notes = sprintf("total=%.6f", r$total))
  }
}
tm_save(do.call(rbind, rows), OUT)
