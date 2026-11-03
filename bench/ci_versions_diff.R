# Compare two tested-versions CSVs (from write_tested_versions.R) and report
# what changed: R version and package versions.
# Usage (from bench/): Rscript ci_versions_diff.R old.csv new.csv
# Prints a markdown summary. When GITHUB_OUTPUT is set, appends changed=true|false.
# A missing old.csv counts as changed (first run).

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2)
read_versions <- function(f) {
  if (!file.exists(f) || file.size(f) == 0) {
    return(NULL)
  }
  d <- tryCatch(
    utils::read.csv(f, stringsAsFactors = FALSE, colClasses = "character"),
    error = function(e) NULL
  )
  # Unreadable or incomplete files count as missing (= changed).
  if (
    is.null(d) ||
      !all(c("package", "version", "r_version") %in% names(d)) ||
      !nrow(d)
  ) {
    return(NULL)
  }
  d
}
old <- read_versions(args[[1]])
new <- read_versions(args[[2]])
if (is.null(new)) {
  stop("new versions file missing: ", args[[2]], call. = FALSE)
}

if (is.null(old)) {
  changed <- TRUE
  lines <- c("No stored versions: first run.")
} else {
  r_old <- old$r_version[[1]]
  r_new <- new$r_version[[1]]
  m <- merge(
    old[, c("package", "version")],
    new[, c("package", "version")],
    by = "package",
    all = TRUE,
    suffixes = c("_old", "_new")
  )
  m[is.na(m)] <- "-"
  diff <- m[m$version_old != m$version_new, , drop = FALSE]
  changed <- r_old != r_new || nrow(diff) > 0
  lines <- character(0)
  if (r_old != r_new) {
    lines <- c(lines, sprintf("R: %s -> %s", r_old, r_new), "")
  }
  if (nrow(diff)) {
    lines <- c(
      lines,
      "| package | stored | now |",
      "|---|---|---|",
      sprintf(
        "| %s | %s | %s |",
        diff$package,
        diff$version_old,
        diff$version_new
      )
    )
  }
  if (!changed) lines <- "No version changes."
}

cat("## Version check\n\n", paste(lines, collapse = "\n"), "\n", sep = "")
gh_out <- Sys.getenv("GITHUB_OUTPUT")
if (nzchar(gh_out)) {
  cat(sprintf("changed=%s\n", tolower(changed)), file = gh_out, append = TRUE)
}
