# Measure what each new R worker pays before running a target: R itself, the
# project .Rprofile (renv activation, checks), and loading the pipeline's packages.
# Usage (from the project root): Rscript startup_cost.R [script=_targets.R] [reps=3]
# Starts fresh R processes; runs the project .Rprofile as any R session would.
# Reads the pipeline definition with tar_manifest(); builds nothing.

args <- commandArgs(trailingOnly = TRUE)
kv <- function(key, default) {
  hit <- grep(paste0("^", key, "="), args, value = TRUE)
  if (length(hit)) sub("^[^=]+=", "", hit[[1]]) else default
}
script <- kv("script", "_targets.R")
reps <- as.integer(kv("reps", "3"))
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")

time_r <- function(expr, vanilla = FALSE) {
  flags <- if (vanilla) "--vanilla" else character(0)
  f <- tempfile(fileext = ".R"); on.exit(unlink(f)); writeLines(expr, f)
  t <- vapply(seq_len(reps), function(i) {
    system.time(system2(rscript, c(flags, f), stdout = FALSE, stderr = FALSE))[["elapsed"]]
  }, numeric(1))
  stats::median(t)
}

man <- targets::tar_manifest(script = script, fields = c("name", "packages", "deployment"))
pk <- man$packages
all_pk <- unique(unlist(pk))
n_t <- nrow(man)
use <- vapply(all_pk, function(p) sum(vapply(pk, function(x) p %in% x, logical(1))), integer(1))
common <- all_pk[use == n_t]
partial <- all_pk[use < n_t]

base <- time_r("NULL", vanilla = TRUE)
profile <- time_r("NULL")
has_rprofile <- file.exists(".Rprofile")
cat(sprintf("R alone (--vanilla): %.2f s   normal start (%s, .Renviron, site profile): %.2f s (+%.2f s)\n",
            base, if (has_rprofile) "project .Rprofile" else "no project .Rprofile", profile, profile - base))
if (has_rprofile && any(grepl("renv", readLines(".Rprofile", warn = FALSE)))) {
  cat("  .Rprofile activates renv: set options(renv.config.synchronized.check = FALSE) or\n",
      "  RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE for workers, and guard checks with interactive().\n", sep = "")
}

# differences below ~0.05 s are timing noise; clamp at 0
load_one <- function(p) max(0, time_r(sprintf("suppressPackageStartupMessages(library(%s))", p)) - profile)
lib <- if (length(all_pk)) setNames(vapply(all_pk, load_one, numeric(1)), all_pk) else numeric(0)
all_load <- if (length(common)) {
  max(0, time_r(sprintf("suppressPackageStartupMessages({%s})", paste0("library(", c("targets", common), ")", collapse = ";"))) - profile)
} else 0

cat(sprintf("\npackages loaded by every target (%d): %.2f s together, with targets\n", length(common), all_load))
if (length(lib)) {
  tab <- data.frame(package = names(lib), load_s = round(lib, 2), used_by = use[names(lib)],
                    of = n_t, every_target = names(lib) %in% common)
  print(tab[order(-tab$load_s), ], row.names = FALSE)
}
heavy_global <- names(lib)[names(lib) %in% common & lib > 0.2]
if (length(heavy_global)) {
  cat("\nheavy packages loaded for every target:", paste(heavy_global, collapse = ", "),
      "\n  if only a few targets call them, move them to those targets' packages = argument,\n",
      "  or call pkg::fn there (loads the namespace on first call, in that worker only).\n")
}
per_worker <- profile + all_load
cat(sprintf("\nper new worker: ~%.2f s. crew keeps workers alive (tasks_max = Inf), so this is paid\n", per_worker),
    sprintf("about once per worker; with tasks_max = 1 it is paid for each of %d targets (~%.0f s).\n", n_t, per_worker * n_t))
