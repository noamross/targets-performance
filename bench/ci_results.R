# Pull CI benchmark results from the bench-results branch and flag what changed.
# Usage (from bench/):
#   Rscript ci_results.R [ref=origin/bench-results] [fetch=TRUE] [out=ci-results] [threshold=1.25]
# Copies latest/<label>/ to <out>/<label>/ (replacing it), then compares each
# label's latest run with its previous run (index.csv) and writes
# <out>/flags.csv: tasks whose median_s moved by more than `threshold` either
# way, tasks whose fastest method changed, and scripts that failed in CI.
# Prints the flags with the reference page each topic feeds.

args <- commandArgs(trailingOnly = TRUE)
kv <- function(key, default) {
  hit <- grep(paste0("^", key, "="), args, value = TRUE)
  if (length(hit)) sub("^[^=]+=", "", hit[[1]]) else default
}
ref <- kv("ref", "origin/bench-results")
out <- kv("out", "ci-results")
threshold <- as.numeric(kv("threshold", "1.25"))
repo <- kv("repo", ".")

git <- function(...) {
  err <- tempfile()
  on.exit(unlink(err))
  res <- suppressWarnings(system2(
    "git",
    c("-C", shQuote(repo), ...),
    stdout = TRUE,
    stderr = err
  ))
  if (!is.null(attr(res, "status"))) {
    res <- c(res, readLines(err, warn = FALSE))
  }
  status <- attr(res, "status")
  if (!is.null(status) && status != 0) {
    stop(
      "git ",
      paste(c(...), collapse = " "),
      " failed:\n",
      paste(res, collapse = "\n"),
      call. = FALSE
    )
  }
  res
}
# Pathspecs (ls-tree, archive) resolve against the working directory; use the top level.
repo <- git("rev-parse", "--show-toplevel")
if (toupper(kv("fetch", "TRUE")) == "TRUE") {
  git("fetch", "origin", "bench-results:refs/remotes/origin/bench-results")
}
show_csv <- function(path) {
  txt <- tryCatch(git("show", paste0(ref, ":", path)), error = function(e) NULL)
  if (is.null(txt) || !length(txt)) {
    return(NULL)
  }
  utils::read.csv(text = paste(txt, collapse = "\n"), stringsAsFactors = FALSE)
}

topic_refs <- c(
  fastfns = "fast-functions",
  vectorize = "vectorization",
  storage = "storage-formats",
  targets_mech = "memory, branching, parallelism, sharing-mori",
  startup = "parallelism",
  remote = "remote-data, query-order",
  blas = "environment"
)

# Copy latest/ into out/
files <- git("ls-tree", "-r", "--name-only", ref, "--", "latest")
labels <- unique(sub(
  "^latest/([^/]+)/.*",
  "\\1",
  grep("^latest/[^/]+/", files, value = TRUE)
))
if (!length(labels)) {
  stop("no labels under latest/ in ", ref, call. = FALSE)
}
# git archive keeps any binary files intact
tmp <- tempfile("ci-results-")
dir.create(tmp)
archive <- file.path(tmp, "latest.tar")
git(
  "archive",
  "--format=tar",
  "-o",
  shQuote(normalizePath(archive, mustWork = FALSE)),
  ref,
  "latest"
)
utils::untar(archive, exdir = tmp)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
for (label in labels) {
  unlink(file.path(out, label), recursive = TRUE)
  file.copy(file.path(tmp, "latest", label), out, recursive = TRUE)
}
unlink(tmp, recursive = TRUE)
cat(sprintf(
  "copied %d labels to %s/: %s\n",
  length(labels),
  out,
  paste(labels, collapse = ", ")
))

# Compare with the previous run per label
key_cols <- c("topic", "task", "n", "method")
timing_tables <- function(prefix) {
  fs <- grep(
    paste0("^", prefix, "[^/]+/results/[^/]+\\.csv$"),
    files_all,
    value = TRUE
  )
  tabs <- lapply(fs, function(f) {
    d <- show_csv(f)
    if (is.null(d) || !all(c(key_cols, "median_s") %in% names(d))) {
      return(NULL)
    }
    d <- d[, c(key_cols, "median_s")]
    d$file <- basename(f)
    d
  })
  do.call(rbind, tabs)
}
files_all <- git("ls-tree", "-r", "--name-only", ref)
index <- show_csv("index.csv")
# Test runs of a few scripts (scope "partial") are not compared
if (!is.null(index) && "scope" %in% names(index)) {
  index <- index[index$scope == "full", , drop = FALSE]
}
flags <- list()
add_flag <- function(label, topic, task, kind, detail) {
  flags[[length(flags) + 1]] <<- data.frame(
    label = label,
    topic = topic,
    task = task,
    kind = kind,
    detail = detail
  )
}
for (label in labels) {
  runs <- if (is.null(index)) {
    character(0)
  } else {
    sort(unique(index$run[index$label == label]), decreasing = TRUE)
  }
  log <- show_csv(paste0("latest/", label, "/ci/run_log.csv"))
  if (!is.null(log)) {
    for (i in which(!log$status %in% c(0, -1))) {
      add_flag(
        label,
        log$topic[i],
        log$script[i],
        "failed",
        sprintf(
          "status %s%s",
          log$status[i],
          if (nzchar(log$killed[i])) paste0(" (", log$killed[i], ")") else ""
        )
      )
    }
  }
  if (length(runs) < 2) {
    next
  }
  new <- timing_tables(paste0("runs/", runs[1], "/", label, "/"))
  old <- timing_tables(paste0("runs/", runs[2], "/", label, "/"))
  if (is.null(new) || is.null(old)) {
    next
  }
  m <- merge(old, new, by = c(key_cols, "file"), suffixes = c("_old", "_new"))
  m <- m[
    is.finite(m$median_s_old) & is.finite(m$median_s_new) & m$median_s_old > 0,
  ]
  r <- m$median_s_new / m$median_s_old
  for (i in which(r > threshold | r < 1 / threshold)) {
    add_flag(
      label,
      m$topic[i],
      paste(m$task[i], m$n[i]),
      "median",
      sprintf(
        "%s: %.3g -> %.3g s (x%.2f)",
        m$method[i],
        m$median_s_old[i],
        m$median_s_new[i],
        r[i]
      )
    )
  }
  fastest <- function(d) {
    g <- split(d, paste(d$topic, d$task, d$n, sep = "\r"))
    vapply(g, function(x) x$method[which.min(x$median_s)], "")
  }
  fo <- fastest(
    m[, c(key_cols, "median_s_old")] |> setNames(c(key_cols, "median_s"))
  )
  fn <- fastest(
    m[, c(key_cols, "median_s_new")] |> setNames(c(key_cols, "median_s"))
  )
  for (k in names(fo)[fo != fn[names(fo)]]) {
    parts <- strsplit(k, "\r")[[1]]
    add_flag(
      label,
      parts[1],
      paste(parts[2], parts[3]),
      "fastest",
      sprintf("%s -> %s", fo[[k]], fn[[k]])
    )
  }
}

flag_df <- if (length(flags)) {
  do.call(rbind, flags)
} else {
  data.frame(
    label = character(),
    topic = character(),
    task = character(),
    kind = character(),
    detail = character()
  )
}
flag_df$reference <- unname(topic_refs[flag_df$topic])
flag_df$reference[is.na(flag_df$reference)] <- flag_df$topic[is.na(
  flag_df$reference
)]
utils::write.csv(flag_df, file.path(out, "flags.csv"), row.names = FALSE)
if (nrow(flag_df)) {
  cat(sprintf("%d flags (%s/flags.csv):\n", nrow(flag_df), out))
  print(flag_df, row.names = FALSE, right = FALSE)
} else {
  cat("no flags\n")
}
