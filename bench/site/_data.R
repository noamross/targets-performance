# Readers for the bench-results branch checkout (BENCH_RESULTS), shared by the site pages.
library(ggplot2)

br <- Sys.getenv("BENCH_RESULTS")
if (!nzchar(br) || !file.exists(file.path(br, "index.csv"))) {
  stop("set BENCH_RESULTS to a checkout of the bench-results branch", call. = FALSE)
}
index <- utils::read.csv(file.path(br, "index.csv"), stringsAsFactors = FALSE)
labels <- sort(list.dirs(file.path(br, "latest"), recursive = FALSE, full.names = FALSE))
latest_run <- function(label) {
  rows <- index[index$label == label & index$scope == "full", ]
  rows[order(rows$run, decreasing = TRUE)[1], ]
}
src <- local({
  runs <- do.call(rbind, lapply(labels, latest_run))
  sprintf(
    "Source: bench-results branch, latest/ (runs %s; commits %s).",
    paste(unique(runs$date), collapse = ", "),
    paste(unique(substr(runs$sha, 1, 7)), collapse = ", ")
  )
})

read_runlog <- function(dir, label) {
  f <- file.path(dir, "ci", "run_log.csv")
  if (!file.exists(f)) return(NULL)
  d <- utils::read.csv(f, stringsAsFactors = FALSE)
  d$label <- label
  d
}
status_name <- function(status, killed) {
  killed[is.na(killed)] <- ""
  ifelse(status == 0, "ok",
    ifelse(status < 0, "skipped",
      ifelse(killed == "memory", "killed: memory",
        ifelse(killed == "timeout", "killed: timeout", "failed"))))
}

# Results rows with a timing column, from every label's latest/ results CSVs.
read_results <- function() {
  rows <- list()
  for (label in labels) {
    files <- list.files(file.path(br, "latest", label), pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
    for (f in grep("/results/", files, value = TRUE)) {
      d <- tryCatch(utils::read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)
      tcol <- intersect(c("median_s", "wall_s"), names(d))[1]
      if (is.null(d) || is.na(tcol) || !all(c("topic", "task", "n", "method") %in% names(d))) next
      rows[[length(rows) + 1]] <- data.frame(
        label = label, topic = d$topic, task = d$task, n = d$n, method = d$method,
        seconds = d[[tcol]], measure = tcol, file = sub(".*/latest/[^/]+/", "", f)
      )
    }
  }
  d <- do.call(rbind, rows)
  d <- d[is.finite(d$seconds) & d$seconds > 0, ]
  key <- paste(d$label, d$topic, d$task, d$n, d$file)
  d$ratio <- d$seconds / stats::ave(d$seconds, key, FUN = min)
  d
}
