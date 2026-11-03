#!/usr/bin/env Rscript
# Read-only profile of a {targets} store: slow, big, branchy and shared targets.
# Usage: Rscript tar_profile.R [store=_targets] [n=20] [script=_targets.R] [measure=target1,target2]
#   store and n may also be given by position: Rscript tar_profile.R _targets 20
#   measure= times one real tar_read() of each named target to calibrate load estimates.
# "downstream" = direct downstream targets in the targets-only network (same
#   count as tar_dag.R); "loads" = reads of the object, counting each branch of
#   a dynamic-branching reader once.
# Writes nothing. MB = bytes / 1e6.

args <- commandArgs(trailingOnly = TRUE)
kv <- list(store = "_targets", n = "20", script = NA_character_, measure = NA_character_)
pos <- c("store", "n")
p <- 0
for (a in args) {
  if (grepl("=", a, fixed = TRUE)) {
    k <- sub("=.*$", "", a); v <- sub("^[^=]*=", "", a)
    kv[[k]] <- v
  } else {
    p <- p + 1
    kv[[pos[p]]] <- a
  }
}
store <- kv$store
n <- as.integer(kv$n)
script <- kv$script

if (!requireNamespace("targets", quietly = TRUE)) stop("targets not installed")
if (!dir.exists(store)) stop("store not found: ", store)

m <- targets::tar_meta(
  store = store,
  fields = c("name", "type", "format", "seconds", "bytes", "time", "parent", "warnings", "error", "repository", "children")
)
m <- as.data.frame(m)
m <- m[m$type != "function", , drop = FALSE]
if (!nrow(m)) stop("no target metadata in store")

fmt <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",")
mb <- function(b) fmt(b / 1e6, 1)
# custom formats store long encoded strings; show as "custom"
short_fmt <- function(f) ifelse(grepl("^format_custom", f), "custom", f)

is_branch <- m$type == "branch"
# pattern rows already hold their branches; count them once
tot_sec <- sum(m$seconds[!is_branch], na.rm = TRUE)
tot_bytes <- sum(m$bytes[!is_branch], na.rm = TRUE)
n_targets <- sum(m$type != "branch" & m$type != "pattern")
tm <- m$time[!is.na(m$time)]

cat("store:", normalizePath(store), "\n")
cat("targets:", n_targets, " branches (current):", sum(m$name[is_branch] %in% unlist(m$children[m$type == "pattern"])), "\n")
cat("total seconds (non-branch rows):", fmt(tot_sec), " total MB:", mb(tot_bytes), "\n")
if (length(tm)) cat("last build:", format(min(tm)), "to", format(max(tm)), "\n")
cat("\n")

show_top <- function(d, key, title) {
  d <- d[!is.na(d[[key]]), , drop = FALSE]
  d <- d[order(-d[[key]]), , drop = FALSE]
  d <- utils::head(d, n)
  cat(title, "\n", sep = "")
  if (!nrow(d)) { cat("  (none)\n\n"); return(invisible()) }
  out <- data.frame(
    name = d$name, type = d$type, format = short_fmt(d$format),
    seconds = fmt(d$seconds, 2), MB = mb(d$bytes),
    pct_sec = fmt(100 * d$seconds / tot_sec, 1)
  )
  print(out, row.names = FALSE, right = FALSE)
  cat("\n")
}

top_m <- m[!is_branch, , drop = FALSE]
show_top(top_m, "seconds", sprintf("top %d by seconds (pct = share of total seconds, all rows):", n))
show_top(top_m, "bytes", sprintf("top %d by bytes (pct = share of total seconds):", n))

# Branches: aggregate per pattern parent.
if (any(is_branch)) {
  current <- if ("children" %in% names(m)) unlist(m$children[m$type == "pattern"], use.names = FALSE) else m$name
  b <- m[is_branch & m$name %in% current, , drop = FALSE]
  agg <- do.call(rbind, lapply(split(b, b$parent), function(x) {
    data.frame(
      parent = x$parent[1], branches = nrow(x),
      sum_sec = sum(x$seconds, na.rm = TRUE),
      median_sec = stats::median(x$seconds, na.rm = TRUE),
      MB = sum(x$bytes, na.rm = TRUE) / 1e6
    )
  }))
  agg <- agg[order(-agg$sum_sec), , drop = FALSE]
  cat("branched targets (pattern parents):\n")
  print(data.frame(
    parent = agg$parent, branches = agg$branches,
    sum_sec = fmt(agg$sum_sec, 2), median_sec = fmt(agg$median_sec, 3),
    MB = fmt(agg$MB, 1),
    flag = ifelse(agg$median_sec < 0.5 & agg$branches > 100, "many tiny branches", "")
  ), row.names = FALSE, right = FALSE)
  cat("\n")
}

# Formats on big objects.
big <- m[!is_branch & !is.na(m$bytes) & m$bytes > 5e8 & m$format %in% c("rds", "qs"), , drop = FALSE]
if (nrow(big)) {
  cat("big objects (>500 MB) in rds/qs format, consider a faster or partial format:\n")
  print(data.frame(name = big$name, format = short_fmt(big$format), MB = mb(big$bytes)), row.names = FALSE)
  cat("\n")
}

# Shared big objects: needs pipeline script for downstream edges.
if (!is.na(script)) {
  if (!file.exists(script)) stop("script not found: ", script)
  net <- utils::capture.output(
    e <- targets::tar_network(
      targets_only = TRUE, outdated = FALSE,
      script = script, store = store
    )$edges
  )
  down <- table(e$from)
  bigm <- m[!is_branch & !is.na(m$bytes) & m$bytes > 1e8, , drop = FALSE]
  bigm$downstream <- as.integer(ifelse(is.na(down[bigm$name]), 0L, down[bigm$name]))
  shared <- bigm[bigm$downstream >= 3, , drop = FALSE]
  cat("objects >100 MB with >=3 direct downstream targets (candidates: memory=\"persistent\", mori sharing, parquet partial reads):\n")
  if (nrow(shared)) {
    shared <- shared[order(-shared$bytes), , drop = FALSE]
    print(data.frame(name = shared$name, format = short_fmt(shared$format), MB = mb(shared$bytes),
                     downstream = shared$downstream), row.names = FALSE)
  } else cat("  (none)\n")
  cat("\n")
} else {
  cat("(pass script=_targets.R for downstream-target and load counts)\n")
}

# Hidden costs: tar_meta()$seconds covers the command only. Saving the value,
# loading it for each reader and starting workers are not in it. Estimate save
# and load time from stored bytes and measured format throughput.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
tp_file <- file.path(here, "..", "format-throughput.csv")
if (file.exists(tp_file)) {
  tp <- utils::read.csv(tp_file)
  tp <- tp[tp$object %in% c("a_numdf", "b_chartbl"), ]
  # conservative: the slower of numeric and character-heavy tables
  rate <- function(f, col) {
    f <- ifelse(grepl("^format_custom", f), "qs", f)
    r <- tapply(tp[[col]], tp$format, min)
    unname(ifelse(f %in% names(r), r[f], NA))
  }
  h <- m[!is_branch & m$type != "pattern" & !is.na(m$bytes) & !m$format %in% c("file", "url", "aws_file"), , drop = FALSE]
  cur <- unlist(m$children[m$type == "pattern"], use.names = FALSE)
  h <- rbind(h, m[is_branch & m$name %in% cur & !is.na(m$bytes), , drop = FALSE])
  mbytes <- h$bytes / 2^20
  # a dynamic-branching reader loads the object once per branch
  n_br <- setNames(lengths(m$children), m$name)
  has_net <- exists("e")
  count_to <- function(wt) {
    r <- tapply(wt, e$from, sum)
    as.integer(ifelse(is.na(r[h$name]), 0L, r[h$name]))
  }
  h$downstream <- if (has_net) count_to(rep(1L, nrow(e))) else NA_integer_
  h$loads <- if (has_net) count_to(ifelse(e$to %in% names(n_br) & n_br[e$to] > 0, n_br[e$to], 1)) else 1L
  h$est_save <- mbytes / rate(h$format, "save_mb_per_s")
  h$est_read <- mbytes / rate(h$format, "load_mb_per_s")
  h$est_load <- h$est_read * h$loads
  h$hidden <- h$est_save + h$est_load
  cmd_total <- sum(m$seconds[!is_branch], na.rm = TRUE)
  cat(sprintf("hidden I/O not in tar_meta seconds (estimate): save %.1f s + loads %.1f s vs command time %.1f s\n",
              sum(h$est_save, na.rm = TRUE), sum(h$est_load, na.rm = TRUE), cmd_total))
  cat("  loads = one read per downstream target, per branch for dynamic-branching readers",
      "(memory = \"transient\" or worker retrieval); persistent memory in one process loads once.\n",
      " under the default retrieval = \"auto\", a pattern that maps over a stored target loads it once in main, so loads overstate.\n")
  if (!has_net) cat("  (no script=: assumes 1 load per target)\n")
  top_h <- h[order(-h$hidden), , drop = FALSE][seq_len(min(n, nrow(h))), ]
  print(data.frame(name = top_h$name, format = short_fmt(top_h$format), MB = mb(top_h$bytes),
                   downstream = top_h$downstream, loads = top_h$loads, est_save_s = fmt(top_h$est_save, 2),
                   est_load_s = fmt(top_h$est_load, 2), command_s = fmt(top_h$seconds, 2)),
        row.names = FALSE, right = FALSE)
  slow_fmt <- top_h$format %in% "rds" & top_h$hidden > 1
  if (any(slow_fmt)) {
    sp <- range(tp$save_mb_per_s[tp$format == "qs"] / tp$save_mb_per_s[tp$format == "rds"])
    cat(sprintf("  rds (gzip) targets above: format = \"qs\" saved %.0f-%.0fx faster in format-throughput.csv.\n", sp[1], sp[2]))
  }
  if (!is.na(kv$measure)) {
    for (nm in strsplit(kv$measure, ",")[[1]]) {
      gc()
      t <- system.time(x <- targets::tar_read_raw(nm, store = store))[["elapsed"]]
      est <- h$est_read[h$name == nm]
      est_txt <- if (length(est) && !is.na(est)) sprintf("%.2f s", est) else "n/a"
      cat(sprintf("  measured load %s: %.2f s (estimate %s per read; in memory %.0f MB)\n",
                  nm, t, est_txt, as.numeric(utils::object.size(x)) / 2^20))
      rm(x)
    }
  }
  cat("  worker startup is also hidden: run scripts/startup_cost.R.\n\n")
}
