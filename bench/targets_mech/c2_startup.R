# Case 2: worker startup: global heavy packages vs per-target; tasks_max Inf vs 1 (fresh worker per task)
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c2_startup.csv"
HEAVY <- c("dplyr", "tidyr", "purrr", "arrow", "duckdb", "data.table")
rows <- list()
mk <- function(global, tmax, s) {
  pre <- tm_prelude(NP4, tasks_max = tmax, packages = if (global) HEAVY)
  loc <- if (global) "" else ', packages = c("dplyr", "arrow")'
  paste(pre, sprintf('
m <- tar_map(values = data.frame(i = 1:22), tar_target(t, spin(%s)))
list(m,
  tar_target(need1, { spin(%s); nrow(dplyr::count(data.frame(a = 1:10), a)) }%s),
  tar_target(need2, { spin(%s); arrow::arrow_table(x = 1:10)$num_rows }%s),
  tar_combine(comb, m[[1]], command = sum(!!!.x)))', s, s, loc, s, loc), sep = "\n")
}
for (s in c(2, 0.2)) for (global in c(TRUE, FALSE)) for (tmax in c("Inf", "1")) {
  meth <- sprintf("packages %s; tasks_max %s", if (global) "global(6 heavy)" else "per-target(2 targets)", tmax)
  r <- tm_run("c2", mk(global, tmax, s))
  rows[[length(rows) + 1]] <- tm_row(sprintf("24x%gs_nproc%d", s, NP4), 24, meth, r, notes = sprintf("crew %d workers seconds_idle 300", NP4))
}
tm_save(do.call(rbind, rows), OUT)
