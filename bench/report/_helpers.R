# Shared loaders and formatters for the bench/report/*.qmd references.
# Base R only, so the references render with any R that has knitr + rmarkdown.
# Every number in a reference comes from pick() (benchmark CSVs) or val()
# (data/sources/values_*.csv); pick() stops unless exactly one row matches.

repo <- normalizePath(file.path(getwd(), "..", ".."))
.cache <- new.env()

csv <- function(path) {
  if (is.null(.cache[[path]])) {
    .cache[[path]] <- utils::read.csv(file.path(repo, "bench", path), stringsAsFactors = FALSE)
  }
  .cache[[path]]
}

# One value from a results table: pick(d, task = "x", method = "y", n = 1e7)
# .rep = k picks the k-th of repeated identical runs (only when rows are true repeats).
pick <- function(d, ..., col = "median_s", .rep = NULL) {
  f <- list(...)
  keep <- rep(TRUE, nrow(d))
  for (k in names(f)) {
    v <- d[[k]]
    if (is.null(v)) stop("no column ", k)
    keep <- keep & if (is.numeric(f[[k]])) !is.na(v) & abs(v - f[[k]]) < 1e-9 * pmax(1, abs(f[[k]])) else v %in% f[[k]]
  }
  hit <- d[keep, , drop = FALSE]
  if (!is.null(.rep) && nrow(hit) >= .rep) hit <- hit[.rep, , drop = FALSE]
  if (nrow(hit) != 1) {
    stop(sprintf("pick(%s) matched %d rows", paste(names(f), f, sep = "=", collapse = ", "), nrow(hit)))
  }
  hit[[col]]
}

# Ratio of two picks that share filters: ratio(d, "slow_method", "fast_method", task = "t", n = 1e7)
ratio <- function(d, slow, fast, ..., by = "method", col = "median_s") {
  a <- do.call(pick, c(list(d), setNames(list(slow), by), list(...), col = col))
  b <- do.call(pick, c(list(d), setNames(list(fast), by), list(...), col = col))
  a / b
}

# Formatters ----
x <- function(r) {
  out <- ifelse(r >= 9.5, formatC(round(r), format = "d", big.mark = ","),
    ifelse(r >= 0.95, formatC(r, format = "f", digits = 1), formatC(r, format = "f", digits = 2)))
  paste0(out, "x")
}
secs <- function(s) {
  ifelse(is.na(s), "-", ifelse(s < 1e-3, sprintf("%.0f µs", s * 1e6),
    ifelse(s < 1, sprintf("%.0f ms", s * 1e3),
      ifelse(s < 10, sprintf("%.1f s", s),
        ifelse(s < 600, sprintf("%.0f s", s), sprintf("%.0f min", s / 60))))))
}
ms <- function(s) sprintf("%.1f ms", s * 1e3)
mb <- function(v) ifelse(v >= 1000, sprintf("%.1f GB", v / 1000), ifelse(v >= 10, sprintf("%.0f MB", v), sprintf("%.1f MB", v)))
num <- function(v, d = 0) formatC(v, format = "f", digits = d, big.mark = ",")
sci <- function(n) sub("e\\+0*", "e", format(n, scientific = TRUE))
pct <- function(v, d = 0) paste0(formatC(100 * v, format = "f", digits = d), "%")

# Published values from research (data/sources/values_*.csv) ----
values <- function() {
  if (is.null(.cache$values)) {
    fs <- Sys.glob(file.path(repo, "data", "sources", "values_*.csv"))
    .cache$values <- do.call(rbind, lapply(fs, utils::read.csv, stringsAsFactors = FALSE))
  }
  .cache$values
}
val <- function(key) {
  v <- values()
  hit <- v[v$key == key, , drop = FALSE]
  if (nrow(hit) != 1) stop("values key ", key, " matched ", nrow(hit), " rows")
  out <- suppressWarnings(as.numeric(hit$value))
  if (is.na(out)) hit$value else out
}
# Source field as shown in a footnote: links in <>, local benchmark paths as
# result names (they are in the source repository, not the installed skill).
src_label <- function(u) {
  if (grepl("^https?://", u)) return(sprintf("<%s>", u))
  if (grepl("^local bench/", u)) {
    return(sprintf("benchmark `%s` in the skill's source repository (`benchmarks.md`)", sub("/results/", "/", sub("^local bench/", "", u), fixed = TRUE)))
  }
  u
}
# Footnote with the source link: `r fn("key")`
fn <- function(key) {
  v <- values()
  hit <- v[v$key == key, , drop = FALSE]
  if (nrow(hit) != 1) stop("values key ", key, " matched ", nrow(hit), " rows")
  url <- src_label(hit$source_url)
  sprintf("^[Source: %s (retrieved %s; %s).]", url, hit$retrieved, hit$quote_or_location)
}

# Provenance line for a table or section ----
# Result files live in the skill's source repository under bench/<topic>/results/
# (benchmarks.md says so once); cite them as <topic>/<file>. Files measured with
# the harness default retrieval = "worker" (before the default "auto" was used)
# say so. Files with the same machine, date and note share one parenthetical.
worker_retrieval <- c("c1_nproc", "c2_startup", "c4_gc", "c6_branching", "c6b_tar_rep", "c7_static", "c8_level")
src_line <- function(paths) {
  info <- lapply(paths, function(p) {
    d <- csv(p)
    m <- if ("machine" %in% names(d)) paste(unique(d$machine), collapse = " / ") else NA
    c <- if ("cores" %in% names(d)) paste(unique(d$cores), collapse = "/") else NA
    rv <- if ("r_version" %in% names(d)) paste(unique(d$r_version), collapse = "/") else NA
    dt <- intersect(c("run_date", "date", "as_of"), names(d))
    dt <- if (length(dt)) paste(sort(unique(d[[dt[1]]])), collapse = ", ") else NA
    desc <- paste(stats::na.omit(c(m, if (!is.na(c)) paste(c, "cores"), if (!is.na(rv)) paste("R", rv))), collapse = ", ")
    note <- if (sub("\\.csv$", "", basename(p)) %in% worker_retrieval) "; `retrieval = \"worker\"`" else ""
    key <- if (nzchar(desc)) sprintf("%s; run %s%s", desc, dt, note) else sprintf("run %s%s", dt, note)
    c(file = sprintf("`%s`", sub("/results/", "/", p, fixed = TRUE)), key = key)
  })
  files <- vapply(info, `[[`, "", "file")
  keys <- vapply(info, `[[`, "", "key")
  parts <- vapply(unique(keys), \(k) sprintf("%s (%s)", paste(files[keys == k], collapse = ", "), k), "")
  paste0("Source: benchmark results ", paste(parts, collapse = "; "), ".")
}

# kable escapes "|" as "&#124;", which GFM shows literally inside code spans; "\\|" works in both.
tbl <- function(d) {
  out <- knitr::kable(d, format = "pipe", row.names = FALSE)
  structure(gsub("&#124;", "\\|", out, fixed = TRUE), class = class(out), format = attr(out, "format"))
}

# Shortcuts ----
# speedup string: sp("fastfns/results/b1_grouped.csv", "base_rowsum", "collapse", task = "t", n = 1e7)
sp <- function(path, slow, fast, ..., by = "method", col = "median_s") x(ratio(csv(path), slow, fast, ..., by = by, col = col))
# formatted time of one row
tm <- function(path, ..., col = "median_s") secs(pick(csv(path), ..., col = col))
# value of one row, unformatted
v1 <- function(path, ..., col = "median_s", .rep = NULL) pick(csv(path), ..., col = col, .rep = .rep)

# Swap table: one row per list(what, use, path, task, n, slow, fast, trap)
swap_tbl <- function(rows, slow_label = "Speedup") {
  d <- do.call(rbind, lapply(rows, function(r) {
    data.frame(
      Replace = r$what, With = r$use,
      n = if (is.null(r$n)) "" else sci(r$n),
      Speedup = sp(r$path, r$slow, r$fast, task = r$task, n = r$n),
      Trap = if (is.null(r$trap)) "" else r$trap
    )
  }))
  if (all(d$Trap == "")) d$Trap <- NULL
  names(d)[names(d) == "Speedup"] <- slow_label
  tbl(d)
}

# Footnote for a sourced claim in data/sources/facts_*.csv: `r ffn("key")`
facts <- function() {
  if (is.null(.cache$facts)) {
    fs <- Sys.glob(file.path(repo, "data", "sources", "facts_*.csv"))
    .cache$facts <- do.call(rbind, lapply(fs, \(f) utils::read.csv(f, stringsAsFactors = FALSE)[c("key", "claim", "source_url", "retrieved", "quote_or_location")]))
  }
  .cache$facts
}
ffn <- function(key) {
  f <- facts()
  hit <- f[f$key == key, , drop = FALSE]
  if (nrow(hit) != 1) stop("facts key ", key, " matched ", nrow(hit), " rows")
  url <- src_label(hit$source_url)
  sprintf("^[Source: %s (retrieved %s; %s).]", url, hit$retrieved, hit$quote_or_location)
}
