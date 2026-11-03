# Summarise per-target Rprof files written by profile_pipeline.R.
# Usage: Rscript profile_summary.R <profiles_dir> [n=8]
# For each target: sampled seconds, top functions by self time, and memory
# allocated when profiled with memory=TRUE. Then the functions that cost the
# most across all targets: a function slow in many targets is one fix that
# speeds up all of them.

args <- commandArgs(trailingOnly = TRUE)
dir <- args[[1]]
n <- if (length(args) > 1) as.integer(sub("^n=", "", args[[2]])) else 8L
files <- list.files(dir, pattern = "\\.Rprof$", full.names = TRUE)
if (!length(files)) stop("no .Rprof files in ", dir)

summ <- lapply(files, function(f) {
  s <- tryCatch(suppressWarnings(utils::summaryRprof(f, memory = "both")),
                error = function(e) tryCatch(utils::summaryRprof(f), error = function(e) NULL))
  if (is.null(s) || !nrow(s$by.self)) return(NULL)
  by <- s$by.self
  data.frame(target = sub("\\.Rprof$", "", basename(f)), fn = gsub('"', "", rownames(by)), self_s = by$self.time,
             mem_mb = if ("mem.total" %in% names(by)) by$mem.total else NA_real_,
             sampled_s = s$sampling.time)
})
d <- do.call(rbind, summ)
if (is.null(d)) stop("profiles were empty (targets too fast for the sampling interval?)")

tot <- tapply(d$sampled_s, d$target, `[`, 1)
cat("targets by sampled time:\n")
for (tg in names(sort(tot, decreasing = TRUE))) {
  x <- d[d$target == tg, ]
  x <- utils::head(x[order(-x$self_s), ], 4)
  cat(sprintf("  %-28s %7.1f s  top: %s\n", tg, tot[[tg]],
              paste(sprintf("%s %.0f%%", x$fn, 100 * x$self_s / tot[[tg]]), collapse = ", ")))
}

agg <- stats::aggregate(cbind(self_s, mem_mb) ~ fn, data = d, FUN = sum, na.action = na.pass)
agg$targets <- as.integer(table(d$fn)[agg$fn])
agg <- utils::head(agg[order(-agg$self_s), ], n)
cat("\nfunctions by self time across all profiled targets:\n")
print(data.frame(fn = agg$fn, self_s = round(agg$self_s, 1), targets = agg$targets,
                 mem_mb = round(agg$mem_mb)), row.names = FALSE)
cat("\nself time = time in the function's own code, not its callees. Open one profile\n",
    "interactively with profvis::profvis(prof_input = '<file>.Rprof') for call trees.\n", sep = "")
