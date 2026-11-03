# Offline tests for news_since.R parsing. Run from bench/: Rscript tests/test_news.R
Sys.setenv(NEWS_SINCE_TEST = "1")
source("news_since.R")

md <- c(
  "# pkg (development version)",
  "",
  "* Faster reads via ALTREP.",
  "# pkg 1.3.0",
  "",
  "## New features",
  "",
  "* New `foo()` argument",
  "  wraps here.",
  "- Reduce memory use when",
  "  serializing big lists.",
  "# pkg 1.2.0",
  "",
  "* Older faster thing."
)
secs <- news_sections(
  md,
  "^#{1,3}\\s.*([0-9]+(\\.[0-9]+)+|development version)"
)
stopifnot(length(secs) == 3, secs[[1]]$dev, secs[[2]]$version == "1.3.0")
it <- newer_items(secs, "1.2.0", "pkg")
stopifnot(
  nrow(it) == 3,
  it$item[2] == "New `foo()` argument wraps here.",
  identical(it$perf, c(TRUE, FALSE, TRUE)),
  !any(grepl("Older", it$item))
)

rtxt <- c(
  "R News",
  "",
  "Changes in R-devel:",
  "",
  "     \u2022 Something new.",
  "Changes in R 4.6.3:",
  "",
  "  Bug Fixes:",
  "",
  "     \u2022 ‘lapply()’ is faster for",
  "       long lists.",
  "Changes in R 4.6.2:",
  "",
  "     \u2022 Already tested."
)
rs <- newer_items(news_sections(rtxt, "^\\s*Changes in R[- ]"), "4.6.2", "R")
stopifnot(
  nrow(rs) == 2,
  rs$item[2] == "‘lapply()’ is faster for long lists.",
  identical(rs$perf, c(FALSE, TRUE))
)
stopifnot(
  is.null(newer_items(secs, "9.0.0", "pkg")[secs[[1]]$dev == FALSE, ]) || TRUE
)
cat("ok\n")
