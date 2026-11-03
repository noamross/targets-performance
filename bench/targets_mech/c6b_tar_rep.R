# Case 6b: simulation-style batching with tarchetypes::tar_rep: 1000 reps x 20 ms.
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c6b_tar_rep.csv"
rows <- list()
AFTER <- 'fs <- list.files("_targets/objects", full.names = TRUE, recursive = TRUE); res$store_files <- length(fs); res$store_bytes <- sum(file.size(fs)); res$nrow <- nrow(tar_read(sims)); res$store_dir_bytes <- sum(file.size(list.files("_targets", full.names = TRUE, recursive = TRUE)))'
src <- function(nproc, B) paste(tm_prelude(nproc),
  sprintf('list(tar_rep(sims, data.frame(v = spin(0.02)), batches = %d, reps = %d), tar_target(total, nrow(sims)))', B, 1000 / B), sep = "\n")
for (np in c(1, NP4)) for (B in c(1000, 100, 40, 10, 8, 4)) {
  if (np == 1 && B %in% c(8, 4)) next
  r <- tm_run("c6b", src(np, B), after = AFTER)
  row <- tm_row("1000reps_20ms", B, sprintf("%s tar_rep batches=%d reps=%d", if (np == 1) "serial" else sprintf("nproc=%d", np), B, 1000 / B), r,
    notes = sprintf("overhead_vs_20s_work: meta %.2f s, wall %.2f s; store objects %d files %.0f KB (whole _targets %.0f KB); rows %d",
      r$sum_meta_s - 20, r$wall[1] - 20, r$store_files, r$store_bytes / 1024, r$store_dir_bytes / 1024, r$nrow))
  rows[[length(rows) + 1]] <- row
}
# tar_map_rep: 2 values x 10 batches x 50 reps = 1000 reps
src_m <- paste(tm_prelude(NP4), 'list(tar_map_rep(msims, data.frame(v = spin(0.02), k = k), values = data.frame(k = 1:2), batches = 10, reps = 50))', sep = "\n")
r <- tm_run("c6b", src_m, after = 'fs <- list.files("_targets/objects", full.names = TRUE, recursive = TRUE); res$store_files <- length(fs); res$store_bytes <- sum(file.size(fs)); res$store_dir_bytes <- sum(file.size(list.files("_targets", full.names = TRUE, recursive = TRUE))); res$nrow <- NA')
rows[[length(rows) + 1]] <- tm_row("1000reps_20ms", 20, sprintf("nproc=%d tar_map_rep 2 values x 10 batches x 50 reps", NP4), r,
  notes = sprintf("store objects %d files %.0f KB", r$store_files, r$store_bytes / 1024))
tm_save(do.call(rbind, rows), OUT)
