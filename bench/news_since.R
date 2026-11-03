# List NEWS entries newer than the skill's tested versions, for R and each
# tested package, and flag the ones that look performance-related. Also lists
# GitHub releases of related system libraries published since the tested date.
# Usage (from bench/):
#   Rscript news_since.R [tested=../skills/targets-performance/tested-versions.csv]
#                        [pkgs=targets,qs2] [r=TRUE] [tools=TRUE] [all=FALSE] [out=<file.md>]
# all=TRUE keeps every newer item, not only flagged ones. Read-only: fetches
# public URLs (CRAN's GitHub mirror, r-source, `gh release list`). Writes the
# markdown report to out= (default: the bench scratch dir) and prints a summary.

perf_re <- paste0(
  "\\b(fast|faster|speed|speedup|perform|slow|memory|alloc|parallel|thread|",
  "openmp|vectori[sz]|cache|altrep|optimi[sz]|efficien|lazy|byte.?code|jit|",
  "blas|lapack|copy|copies|serializ|compress|latency|overhead|throughput)"
)
tools_repos <- c(
  "OpenMathLib/OpenBLAS",
  "duckdb/duckdb",
  "apache/arrow",
  "facebook/zstd",
  "curl/curl"
)

# Split NEWS lines into sections at headings that carry a version.
# Returns a list of list(version, dev, lines).
news_sections <- function(lines, heading_re) {
  starts <- grep(heading_re, lines, ignore.case = TRUE, perl = TRUE)
  if (!length(starts)) {
    return(list())
  }
  ends <- c(starts[-1] - 1, length(lines))
  Map(
    function(s, e) {
      h <- lines[[s]]
      v <- regmatches(h, regexpr("[0-9]+(\\.[0-9]+)+", h))
      list(
        heading = trimws(h),
        version = if (length(v)) v else NA_character_,
        dev = grepl("devel|development|patched", h, ignore.case = TRUE),
        lines = lines[seq_len(e - s) + s]
      )
    },
    starts,
    ends
  )
}

# Join wrapped lines into bullet items (markdown -, *, + or Rd2txt's bullet).
news_items <- function(lines) {
  is_bullet <- grepl("^\\s*([-*+]|\u2022)\\s+", lines)
  keep <- nzchar(trimws(lines)) & !grepl("^\\s*#", lines)
  id <- cumsum(is_bullet)
  items <- tapply(lines[keep & id > 0], id[keep & id > 0], function(x) {
    paste(trimws(sub("^\\s*([-*+]|\u2022)\\s+", "", x)), collapse = " ")
  })
  unname(as.character(items))
}

is_newer <- function(sec, tested) {
  if (sec$dev) {
    return(TRUE)
  }
  if (is.na(sec$version)) {
    return(FALSE)
  }
  isTRUE(tryCatch(
    package_version(sec$version) > package_version(tested),
    error = function(e) FALSE
  ))
}

# Newer sections -> data.frame(source, version, item, perf)
newer_items <- function(sections, tested, source) {
  rows <- lapply(Filter(\(s) is_newer(s, tested), sections), function(s) {
    it <- news_items(s$lines)
    if (!length(it)) {
      return(NULL)
    }
    data.frame(
      source = source,
      version = if (s$dev) s$heading else s$version,
      item = it,
      perf = grepl(perf_re, it, ignore.case = TRUE, perl = TRUE)
    )
  })
  do.call(rbind, rows)
}

fetch_lines <- function(url) {
  f <- tempfile()
  on.exit(unlink(f))
  ok <- tryCatch(
    utils::download.file(url, f, quiet = TRUE, mode = "wb") == 0,
    error = function(e) FALSE,
    warning = function(w) FALSE
  )
  if (ok) readLines(f, warn = FALSE, encoding = "UTF-8") else NULL
}

r_news <- function(tested) {
  url <- "https://raw.githubusercontent.com/wch/r-source/trunk/doc/NEWS.Rd"
  rd <- fetch_lines(url)
  if (is.null(rd)) {
    return(list(url = url, items = NULL))
  }
  f <- tempfile(fileext = ".Rd")
  txt <- tempfile(fileext = ".txt")
  on.exit(unlink(c(f, txt)))
  writeLines(rd, f, useBytes = TRUE)
  tools::Rd2txt(
    tools::parse_Rd(f),
    out = txt,
    options = list(underline_titles = FALSE)
  )
  secs <- news_sections(
    readLines(txt, warn = FALSE, encoding = "UTF-8"),
    "^\\s*Changes in R[- ]"
  )
  list(url = url, items = newer_items(secs, tested, "R"))
}

pkg_news <- function(pkg, tested) {
  url <- sprintf("https://raw.githubusercontent.com/cran/%s/HEAD/NEWS.md", pkg)
  md <- fetch_lines(url)
  if (is.null(md)) {
    return(list(url = url, items = NULL))
  }
  secs <- news_sections(
    md,
    "^#{1,3}\\s.*([0-9]+(\\.[0-9]+)+|development version)"
  )
  list(url = url, items = newer_items(secs, tested, pkg))
}

tool_releases <- function(repo, since) {
  res <- suppressWarnings(system2(
    "gh",
    c(
      "release",
      "list",
      "-R",
      repo,
      "--limit",
      "20",
      "--json",
      "tagName,publishedAt",
      "--jq",
      shQuote(".[] | [.tagName, .publishedAt] | @tsv")
    ),
    stdout = TRUE,
    stderr = FALSE
  ))
  if (!length(res) || !is.null(attr(res, "status"))) {
    return(NULL)
  }
  d <- utils::read.table(
    text = res,
    sep = "\t",
    col.names = c("tag", "published"),
    stringsAsFactors = FALSE
  )
  d <- d[as.Date(substr(d$published, 1, 10)) > as.Date(since), , drop = FALSE]
  if (nrow(d)) {
    cbind(
      repo = repo,
      d,
      url = sprintf("https://github.com/%s/releases/tag/%s", repo, d$tag)
    )
  } else {
    NULL
  }
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  kv <- function(key, default) {
    hit <- grep(paste0("^", key, "="), args, value = TRUE)
    if (length(hit)) sub("^[^=]+=", "", hit[[1]]) else default
  }
  source("_common.R")
  tv <- utils::read.csv(
    kv("tested", "../skills/targets-performance/tested-versions.csv"),
    stringsAsFactors = FALSE
  )
  pkgs <- kv("pkgs", NA)
  if (!is.na(pkgs)) {
    tv <- tv[tv$package %in% strsplit(pkgs, ",")[[1]], ]
  }
  keep_all <- toupper(kv("all", "FALSE")) == "TRUE"
  out <- kv(
    "out",
    file.path(bench_scratch("news"), sprintf("news-since-%s.md", Sys.Date()))
  )
  tested_date <- tv$tested[1]

  md <- c(
    sprintf(
      "# NEWS since tested versions (tested %s, R %s; fetched %s)",
      tested_date,
      tv$r_version[1],
      Sys.Date()
    ),
    ""
  )
  report <- function(name, tested, res) {
    it <- res$items
    n_new <- if (is.null(it)) 0 else length(unique(it$version))
    n_perf <- if (is.null(it)) 0 else sum(it$perf)
    cat(sprintf(
      "%-12s tested %-10s %s\n",
      name,
      tested,
      if (is.null(it) && is.null(fetch_lines(res$url))) {
        "no NEWS.md found"
      } else {
        sprintf("%d newer versions, %d flagged items", n_new, n_perf)
      }
    ))
    if (is.null(it)) {
      return(invisible())
    }
    show <- if (keep_all) it else it[it$perf, ]
    md <<- c(
      md,
      sprintf("## %s (tested %s)", name, tested),
      "",
      sprintf("Source: %s", res$url),
      ""
    )
    if (nrow(show)) {
      md <<- c(
        md,
        sprintf(
          "- **%s**%s %s",
          show$version,
          ifelse(show$perf, " [perf]", ""),
          show$item
        ),
        ""
      )
    } else {
      md <<- c(md, "No flagged items.", "")
    }
  }
  if (toupper(kv("r", "TRUE")) == "TRUE") {
    report("R", tv$r_version[1], r_news(tv$r_version[1]))
  }
  for (i in seq_len(nrow(tv))) {
    report(tv$package[i], tv$version[i], pkg_news(tv$package[i], tv$version[i]))
  }
  if (toupper(kv("tools", "TRUE")) == "TRUE") {
    if (!nzchar(Sys.which("gh"))) {
      cat("gh not found: skipping tool releases\n")
    } else {
      rel <- do.call(
        rbind,
        lapply(tools_repos, tool_releases, since = tested_date)
      )
      cat(sprintf(
        "tools        %d releases since %s\n",
        if (is.null(rel)) 0 else nrow(rel),
        tested_date
      ))
      md <- c(
        md,
        sprintf("## System library releases since %s", tested_date),
        ""
      )
      md <- c(
        md,
        if (is.null(rel)) {
          "None."
        } else {
          sprintf(
            "- %s %s (%s): %s",
            rel$repo,
            rel$tag,
            substr(rel$published, 1, 10),
            rel$url
          )
        },
        ""
      )
    }
  }
  writeLines(md, out, useBytes = TRUE)
  cat("report:", out, "\n")
}

if (Sys.getenv("NEWS_SINCE_TEST") != "1") {
  main()
}
