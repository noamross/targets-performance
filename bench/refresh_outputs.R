# Regenerate everything derived from benchmark results, then check the skill.
# Usage (from the repo root or bench/): Rscript bench/refresh_outputs.R
# Writes: skills/targets-performance/tested-versions.csv, skills/targets-performance/format-throughput.csv,
#         skills/targets-performance/references/*.md. Runs no benchmarks.
# Private-name check: regexes (one per line) from <repo root>/.private-names, if present.
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
here <- normalizePath(getwd())
root <- if (basename(here) == "bench") dirname(here) else here
fail <- function(...) { message("refresh: ", ...); quit(save = "no", status = 1L) }
run <- function(cmd, args, wd) {
  old <- setwd(wd); on.exit(setwd(old))
  out <- suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = TRUE))
  list(out = out, status = attr(out, "status") %||% 0L)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

for (s in c("write_tested_versions.R", "storage/write_throughput.R")) {
  r <- run(rscript, s, file.path(root, "bench"))
  if (r$status != 0) fail(s, " failed:\n", paste(utils::tail(r$out, 15), collapse = "\n"))
}
r <- run("quarto", c("render", "bench/report"), root)
if (r$status != 0 || any(grepl("ERROR|Error|WARN", r$out))) fail("render failed:\n", paste(utils::tail(r$out, 20), collapse = "\n"))
refs <- list.files(file.path(root, "skills/targets-performance/references"), "\\.md$")
cat("refresh: references rendered:", length(refs), "files\n")

pn <- file.path(root, ".private-names")
if (file.exists(pn)) {
  pats <- trimws(readLines(pn, warn = FALSE)); pats <- pats[nzchar(pats) & !startsWith(pats, "#")]
  files <- list.files(file.path(root, "skills"), recursive = TRUE, full.names = TRUE)
  for (f in files) {
    txt <- tryCatch(readLines(f, warn = FALSE), error = function(e) character(), warning = function(w) character())
    for (p in pats) {
      hit <- grep(p, txt, ignore.case = TRUE)
      if (length(hit)) { cat(sprintf("%s:%d: %s\n", f, hit, txt[hit]), sep = ""); fail("private names found under skills/ (see above)") }
    }
  }
}

for (f in list.files(file.path(root, "data/sources"), "\\.csv$", full.names = TRUE)) {
  n <- utils::count.fields(f, sep = ",", quote = "\"")
  if (any(n > n[1], na.rm = TRUE)) fail("malformed rows in ", f, ": ", paste(which(n > n[1]), collapse = " "))
}
cat("refresh: ok\n")
