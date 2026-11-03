# Load time of packages in fresh R sessions. Run: cd bench && Rscript startup/pkg_load_time.R
pkgs <- c("targets","crew","dplyr","tidyverse","ggplot2","arrow","duckdb","sf","data.table","collapse","qs2")
rs <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
# Run an R expression in a fresh Rscript via a temp script file (no shell quoting).
run_expr <- function(expr) {
  f <- tempfile(fileext = ".R"); on.exit(unlink(f)); writeLines(expr, f)
  system2(rs, f, stdout = TRUE)
}
one <- function(p, mode) {
  expr <- if (mode == "attach") sprintf("t<-system.time(library(%s))[['elapsed']];cat(t)", p)
          else sprintf("t<-system.time(loadNamespace('%s'))[['elapsed']];cat(t)", p)
  if (!requireNamespace(p, quietly = TRUE)) return(NA_real_)
  as.numeric(run_expr(expr))
}
res <- do.call(rbind, lapply(pkgs, \(p) data.frame(pkg = p,
  attach_s = one(p, "attach"), namespace_s = one(p, "ns"),
  attach2_s = one(p, "attach"))))
base <- as.numeric(run_expr("cat(system.time(NULL)[['elapsed']])"))
t0 <- system.time(run_expr("1"))[["elapsed"]]
res$bare_rscript_s <- t0
res$r_version <- as.character(getRversion()); res$date <- as.character(Sys.Date())
print(res); write.csv(res, "startup/results/pkg_load_time.csv", row.names = FALSE)
