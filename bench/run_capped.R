# Run one benchmark script under a memory cap on its process tree (via run_suite.R).
# Usage (from bench/): Rscript run_capped.R <script.R> [cap_gb] [args...]
# Default cap: the smaller of 4 GB and 25% of currently available memory.
# Exit status: 0 ok, 137 over the cap, 124 timeout, 1 failed. Output goes to ci/logs/<script>.log.
a <- commandArgs(trailingOnly = TRUE)
if (!length(a)) stop("usage: Rscript run_capped.R <script.R> [cap_gb] [args...]", call. = FALSE)
script <- a[[1]]
cap_gb <- suppressWarnings(as.numeric(if (length(a) >= 2) a[[2]] else NA))
sargs <- if (length(a) >= 3) a[-(1:2)] else character(0)
if (is.na(cap_gb)) {
  cap_gb <- min(4, ps::ps_system_memory()$avail / 2^30 / 4)
}
tmp <- tempfile("run-capped-"); dir.create(tmp); on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
suite <- data.frame(
  script = script, topic = basename(dirname(script)), args = paste(sargs, collapse = ";"),
  cap_gb = cap_gb, min_cores = NA, min_ram_gb = NA, est_min = NA, ci = TRUE, needs = "", notes = ""
)
utils::write.csv(suite, file.path(tmp, "suite.csv"), row.names = FALSE)
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
status <- system2(rscript, c("run_suite.R", paste0("suite=", file.path(tmp, "suite.csv")),
                             paste0("log=", file.path(tmp, "log.csv")), paste0("cap_gb=", cap_gb)))
quit(save = "no", status = status)
