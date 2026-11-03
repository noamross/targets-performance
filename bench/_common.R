# Shared helpers for benchmark scripts. Source from bench/: source("_common.R")

.libPaths(c(.libPaths(), ".extralib"))

# Scratch space for big temporary files and toy stores, outside the repo.
# Set BENCH_SCRATCH to choose it (CI sets it to the runner's temp dir).
bench_scratch <- function(sub) {
  root <- Sys.getenv("BENCH_SCRATCH", file.path(dirname(tempdir()), "targets-performance-bench"))
  d <- file.path(root, sub)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# Usable cores: respects cgroup/CI limits when parallelly is installed.
bench_cores <- function() {
  n <- if (requireNamespace("parallelly", quietly = TRUE)) parallelly::availableCores() else parallel::detectCores()
  n <- as.integer(n)
  if (is.na(n) || n < 1L) 1L else n
}

# Keep the values of x that fit on this machine (at least the smallest one).
cap_n <- function(x, max = bench_cores()) {
  out <- x[x <= max]
  if (length(out)) out else min(x)
}

# Thread/worker counts to scan: the base values that fit, plus all cores when
# that is not already one of them.
thread_set <- function(base = c(1, 2, 4, 8), max = bench_cores()) {
  sort(unique(c(base[base <= max], if (max <= max(base)) max)))
}

# Worker count for crew/mirai pools: k, limited to the cores available, never
# below 2 so the pool stays a real pool.
np_cap <- function(k, max = bench_cores()) as.integer(max(2L, min(k, max)))

# Path of the Rscript binary that runs this R.
rscript_bin <- function() file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")

# Run `expr` only when `ok`; otherwise print why and return NULL.
skip_msg <- function(ok, what, why) {
  if (!ok) message(sprintf("skipping %s: %s", what, why))
  ok
}

# Memory budget for one benchmark process, in MB. run_suite.R sets
# BENCH_MEM_CAP_MB; otherwise the smaller of 4 GB and 25% of available memory.
mem_budget_mb <- function() {
  cap <- as.numeric(Sys.getenv("BENCH_MEM_CAP_MB", NA))
  if (!is.na(cap)) return(cap)
  min(4096, ps::ps_system_memory()$avail / 2^20 / 4)
}

# Stop before building data that won't fit. `object_mb` is the size of one
# copy; `copies` counts the copies alive at once (inputs, outputs, bench::mark
# results, serialization buffers). Be generous: 4-6 for most benchmarks.
check_fits <- function(object_mb, copies = 5, label = "") {
  need <- object_mb * copies
  budget <- mem_budget_mb()
  if (need > budget) {
    stop(sprintf("%s needs ~%.0f MB (%g MB x %g copies) > budget %.0f MB; use a smaller n",
                 label, need, object_mb, copies, budget), call. = FALSE)
  }
  invisible(TRUE)
}

# TRUE when check_fits() would pass; use to skip or shrink instead of stopping.
# Headroom: the budget minus what this R process already holds (packages,
# earlier objects), with 20% slack for allocator and bench::mark overhead.
free_budget_mb <- function() {
  rss <- tryCatch(ps::ps_memory_info()[["rss"]] / 2^20, error = function(e) 0)
  (mem_budget_mb() - rss) * 0.8
}
fits <- function(object_mb, copies = 5) object_mb * copies <= free_budget_mb()

# For loops: TRUE if it fits, else print why and return FALSE (caller does `next`).
fits_or_skip <- function(object_mb, copies = 5, label = "") {
  ok <- fits(object_mb, copies)
  if (!ok) message(sprintf("skipping %s: needs ~%.0f MB > free budget %.0f MB", label, object_mb * copies, free_budget_mb()))
  ok
}

# Largest n from `ns` (ascending) whose object (bytes_per_row each) fits; NA if none.
max_fit_n <- function(ns, bytes_per_row, copies = 5) {
  ok <- ns[vapply(ns, \(n) fits(n * bytes_per_row / 2^20, copies), logical(1))]
  if (length(ok)) max(ok) else NA
}

bench_env <- function() {
  data.frame(
    machine = Sys.getenv("BENCH_ENV_LABEL", paste(Sys.info()[["sysname"]], Sys.info()[["machine"]])),
    cores = bench_cores(),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    run_date = format(Sys.Date())
  )
}

pkg_versions <- function(pkgs) {
  paste(pkgs, vapply(pkgs, \(p) as.character(utils::packageVersion(p)), ""), sep = " ", collapse = "; ")
}

# Turn a bench::mark() result into a plain data frame with ratios to the
# fastest expression, then append to results/<file>.csv.
# `same` is a named logical: did each expression's output equal the reference?
record_mark <- function(mark, topic, task, n, file, pkgs, same = NULL, notes = "") {
  expr <- as.character(mark$expression)
  med <- as.numeric(mark$median)
  out <- data.frame(
    topic = topic,
    task = task,
    n = n,
    method = expr,
    median_s = med,
    ratio_to_fastest = med / min(med),
    mem_alloc_mb = as.numeric(mark$mem_alloc) / 2^20,
    n_itr = mark$n_itr,
    identical_to_ref = if (is.null(same)) NA else unname(same[expr]),
    notes = notes,
    packages = pkg_versions(pkgs)
  )
  out <- cbind(out, bench_env())
  write_result(out, file)
  invisible(out)
}

# Append rows to bench/<topic>/results/<file>.csv, replacing earlier rows for the
# same topic/task/n/method so reruns don't duplicate.
write_result <- function(rows, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(file)) {
    old <- utils::read.csv(file, stringsAsFactors = FALSE)
    key <- \(d) paste(d$topic, d$task, d$n, d$method)
    old <- old[!key(old) %in% key(rows), , drop = FALSE]
    rows <- rbind(old[, names(rows), drop = FALSE], rows)
  }
  utils::write.csv(rows, file, row.names = FALSE)
}

# Check each candidate output against a reference; returns a named logical.
same_as <- function(ref, ..., tolerance = NULL) {
  cands <- list(...)
  vapply(cands, function(x) {
    if (is.null(tolerance)) identical(ref, x) else isTRUE(all.equal(ref, x, tolerance = tolerance, check.attributes = FALSE))
  }, logical(1))
}
