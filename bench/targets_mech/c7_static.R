# Case 7: static (tar_map) vs dynamic (pattern = map) branching overhead, trivial work, serial.
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c7_static.csv"
rows <- list()
for (n in c(6, 60, 300)) for (rep in 1:2) {
  stat <- paste(tm_prelude(1), sprintf('m <- tar_map(values = data.frame(i = 1:%d), tar_target(t, spin(0.05)))
list(m, tar_combine(comb, m[[1]], command = sum(!!!.x)))', n), sep = "\n")
  dyn <- paste(tm_prelude(1), sprintf('list(tar_target(ids, 1:%d), tar_target(t, spin(0.05), pattern = map(ids)), tar_target(comb, sum(t)))', n), sep = "\n")
  for (k in c("static tar_map", "dynamic map")) {
    r <- tm_run("c7", if (k == "static tar_map") stat else dyn)
    rows[[length(rows) + 1]] <- tm_row("n_x_50ms_serial", n, sprintf("%s rep%d", k, rep), r,
      notes = sprintf("overhead per target = (wall - n*0.05)/n = %.1f ms", (r$wall[1] - n * 0.05) / n * 1000))
  }
}
tm_save(do.call(rbind, rows), OUT)
