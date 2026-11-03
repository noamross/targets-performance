# List (or install) the benchmark packages named in rproj.toml [dependencies].
# Usage (from bench/): Rscript deps.R [install=FALSE]
# Uses the repositories configured in your R session. rig users can run
# `rig proj sync` instead.
lines <- readLines("rproj.toml", warn = FALSE)
start <- grep("^\\[dependencies\\]", lines)
end <- c(grep("^\\[", lines), length(lines) + 1)
end <- min(end[end > start]) - 1
dep <- sub("^\"?([A-Za-z0-9.]+)\"?\\s*=.*", "\\1", lines[(start + 1):end])
dep <- setdiff(dep[nzchar(dep) & !grepl("^#", dep)], "R")
missing <- dep[!nzchar(vapply(dep, \(p) system.file(package = p), ""))]
cat(sprintf(
  "%d packages in rproj.toml, %d missing%s\n",
  length(dep),
  length(missing),
  if (length(missing)) paste0(": ", paste(missing, collapse = " ")) else ""
))
if (
  length(missing) &&
    toupper(sub(
      "^install=",
      "",
      grep("^install=", commandArgs(TRUE), value = TRUE)[1]
    )) %in%
      "TRUE"
) {
  utils::install.packages(missing)
}
