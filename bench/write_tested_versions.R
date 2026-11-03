# Write skills/targets-performance/tested-versions.csv: the package versions the
# skill's benchmarks ran with. Run from bench/ after any benchmark rerun:
#   Rscript write_tested_versions.R [out=path.csv]
# CI passes out= to write the versions it installed somewhere else.
source("_common.R")
out_arg <- grep("^out=", commandArgs(trailingOnly = TRUE), value = TRUE)
out_file <- if (length(out_arg)) sub("^out=", "", out_arg[[1]]) else "../skills/targets-performance/tested-versions.csv"

pkgs <- c("targets", "tarchetypes", "crew", "mirai", "qs2", "mori", "zap", "nanoparquet", "arrow",
          "duckdb", "duckplyr", "dbplyr", "collapse", "data.table", "kit", "Rfast", "Rfast2",
          "fastverse", "fst", "stringi", "vctrs", "purrr", "dplyr", "curl", "httr2", "bench")
installed <- pkgs[nzchar(vapply(pkgs, \(p) system.file(package = p), ""))]
env <- bench_env()
out <- data.frame(
  package = installed,
  version = vapply(installed, \(p) as.character(utils::packageVersion(p)), ""),
  r_version = env$r_version,
  platform = R.version$platform,
  tested = env$run_date
)
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, out_file, row.names = FALSE)
cat("wrote", nrow(out), "packages\n")
