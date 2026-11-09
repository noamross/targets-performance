# Tests for run_suite.R script selection and memory caps (dry runs only).
# Run from bench/: Rscript tests/test_run_suite.R   (base R; prints "ok" or stops)

rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
tmp <- tempfile("test-suite-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
suite_file <- file.path(tmp, "suite.csv")
utils::write.csv(data.frame(
  script = c("a/small.R", "a/huge.R", "b/none.R"),
  topic = c("a", "a", "b"),
  args = "",
  cap_gb = c(0.5, 1000, NA),
  min_cores = 1,
  min_ram_gb = 0,
  est_min = 1,
  ci = c(TRUE, TRUE, FALSE),
  needs = "",
  notes = ""
), suite_file, row.names = FALSE)

run <- function(...) {
  out <- suppressWarnings(system2(rscript, c("run_suite.R", paste0("suite=", suite_file), "dry=TRUE", ...),
                                  stdout = TRUE, stderr = TRUE))
  list(status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"), out = out)
}
caps <- function(res) {
  csv <- res$out[grepl("^\"?[a-z]/", res$out) | grepl("^\"?script\"?,", res$out)]
  d <- utils::read.csv(text = csv)
  stats::setNames(d$cap_used_gb, d$script)
}
total_gb <- ps::ps_system_memory()$total / 2^30

# Cap: the suite.csv cap, bounded by 60% of total RAM; 4 GB when unset.
r <- run()
stopifnot(r$status == 0)
cp <- caps(r)
stopifnot(
  isTRUE(all.equal(cp[["a/small.R"]], 0.5, tolerance = 0.01)),
  isTRUE(all.equal(cp[["a/huge.R"]], 0.6 * total_gb, tolerance = 0.01)),
  isTRUE(all.equal(cp[["b/none.R"]], min(4, 0.6 * total_gb), tolerance = 0.01))
)

# cap_gb= overrides every row, still bounded by total RAM.
cp <- caps(run("cap_gb=0.25"))
stopifnot(all(abs(cp - 0.25) < 0.01))

# An empty selection (e.g. a CI shard with none of the requested scripts) exits 0.
r <- run("topics=a", "scripts=b/none.R")
stopifnot(r$status == 0, any(grepl("no scripts selected", r$out)))

# Every CI topic in suite.csv is in exactly one shard of the workflow matrix.
wf <- readLines(file.path("..", ".github", "workflows", "benchmarks.yml"))
shard_lines <- regmatches(wf, regexpr("\\{ id: [0-9]+, topics: [^}]+\\}", wf))
shard_topics <- unlist(strsplit(gsub('.*topics: "?([^"}]+)"?.*', "\\1", shard_lines), ","))
shard_topics <- trimws(shard_topics)
real <- utils::read.csv("suite.csv", stringsAsFactors = FALSE)
ci_topics <- unique(real$topic[real$ci])
stopifnot(
  length(shard_lines) > 0,
  !anyDuplicated(shard_topics),
  setequal(shard_topics, ci_topics)
)

cat("ok\n")
