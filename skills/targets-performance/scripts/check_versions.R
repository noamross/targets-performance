# Compare installed package versions with the versions this skill was tested on.
# Usage: Rscript check_versions.R [path/to/tested-versions.csv]
# Default csv: ../tested-versions.csv relative to this script.
# Prints only packages that differ; advice tied to a package may be stale when
# its major or minor version differs from the tested one.

args <- commandArgs(trailingOnly = TRUE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
csv <- if (length(args)) args[[1]] else file.path(here, "..", "tested-versions.csv")
tested <- utils::read.csv(csv, stringsAsFactors = FALSE)

cat(sprintf("skill tested %s on R %s (%s)\n", tested$tested[1], tested$r_version[1], tested$platform[1]))
cat(sprintf("this session: R %s.%s (%s)\n\n", R.version$major, R.version$minor, R.version$platform))

installed <- vapply(tested$package, function(p) {
  if (nzchar(system.file(package = p))) as.character(utils::packageVersion(p)) else NA_character_
}, "")

major_minor <- function(v) sub("^(\\d+\\.\\d+).*", "\\1", v)
status <- ifelse(is.na(installed), "not installed",
  ifelse(installed == tested$version, "same",
    ifelse(major_minor(installed) != major_minor(tested$version),
      ifelse(package_version(installed) > package_version(tested$version),
             "NEWER (major/minor): recheck advice", "OLDER (major/minor): upgrade may help"),
      "patch differs")))

out <- data.frame(package = tested$package, tested = tested$version, installed = installed, status = status)
diff <- out[!out$status %in% c("same", "not installed"), ]
if (nrow(diff)) print(diff, row.names = FALSE) else cat("all installed packages match tested versions\n")
missing <- out$package[out$status == "not installed"]
if (length(missing)) cat("\nnot installed:", paste(missing, collapse = ", "), "\n")
if (any(grepl("major/minor", status))) {
  cat("\nFor NEWER packages, check NEWS for performance or default changes before trusting the\n",
      "skill's numbers; consider running the targets-performance-update skill.\n", sep = "")
}
