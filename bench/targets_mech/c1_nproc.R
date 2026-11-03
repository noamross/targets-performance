# Case 1: NPROC scaling, per-target overhead (serial vs crew; deployment main for tiny targets)
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c1_nproc.csv"
rows <- list()
add <- function(...) { rows[[length(rows) + 1]] <<- tm_row(...) }

src24 <- function(nproc, crew = nproc > 1, ...) paste(tm_prelude(nproc, crew = crew, ...), '
m <- tar_map(values = data.frame(i = 1:24), tar_target(t, spin(2)))
list(m, tar_combine(comb, m[[1]], command = sum(!!!.x)))', sep = "\n")
for (np in c(1, unique(c(2, NP4, NP6)))) {
  r <- tm_run(sprintf("c1_24x2s_np%d", np), src24(np))
  add("24x2s", 24, sprintf("nproc=%d (%s)", np, if (np > 1) "crew" else "serial, no controller"), r, notes = "24 targets x 2 s CPU + combine")
}
r <- tm_run("c1_24x2s_crew1", src24(1, crew = TRUE))
add("24x2s", 24, "nproc=1 crew 1 worker", r, notes = "crew with a single worker (deployment worker)")

src200 <- function(nproc, crew = nproc > 1, dep = NULL, ...) paste(tm_prelude(nproc, crew = crew, ...), sprintf('
m <- tar_map(values = data.frame(i = 1:200), tar_target(t, spin(0.02)%s))
list(m, tar_combine(comb, m[[1]], command = sum(!!!.x), deployment = "main"))',
  if (is.null(dep)) "" else sprintf(', deployment = "%s"', dep)), sep = "\n")
for (rep in 1:2) {
  r <- tm_run("c1_200x20ms_serial", src200(1)); add("200x20ms", 200, "serial", r, notes = sprintf("rep %d", rep))
}
for (np in unique(c(2, NP4, NP6))) {
  r <- tm_run("c1_200x20ms_crew", src200(np)); add("200x20ms", 200, sprintf("crew nproc=%d deployment worker", np), r)
}
r <- tm_run("c1_200x20ms_crewmain", src200(NP4, dep = "main")); add("200x20ms", 200, sprintf("crew nproc=%d, deployment main for tiny targets", NP4), r)
r <- tm_run("c1_200x20ms_crew1", src200(1, crew = TRUE)); add("200x20ms", 200, "crew 1 worker deployment worker", r)
out <- do.call(rbind, rows)
tm_save(out, OUT)
