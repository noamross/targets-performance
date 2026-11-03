# Case 4: tar_option_set(garbage_collection = 0 / 1 / 10) on the case-3 pipeline (300 MB big, 6 consumers, transient).
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c4_gc.csv"
pipe <- function(...) paste(tm_prelude(...), '
big_t <- tar_target(big, make_big(300), format = fmt_logged)
cons <- lapply(1:6, function(i) tar_target_raw(paste0("c", i), substitute(consume(big, I), list(I = i)), format = "rds"))
c(list(big_t), cons, list(tar_target(final, sum(c1, c2, c3, c4, c5, c6))))', sep = "\n")
rows <- list()
for (rep in 1:3) for (np in c(1, NP3)) for (gc in c(0, 1, 10)) {
  if (!tm_fits(300 * (2 + 2 * np), sprintf("c4 nproc %d", np))) next
  r <- tm_run("c4", pipe(np, memory = "transient", gc = gc))
  rows[[length(rows) + 1]] <- tm_row("big300_gc", 300, sprintf("%s gc=%d rep%d", if (np == 1) "serial" else sprintf("nproc=%d", np), gc, rep), r)
}
tm_save(do.call(rbind, rows), OUT)
d <- do.call(rbind, rows); d$cfg <- sub(" rep.*", "", d$method)
print(aggregate(cbind(wall_s, peak_rss_mb) ~ cfg, d, median))
