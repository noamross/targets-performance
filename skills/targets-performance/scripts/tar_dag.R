# Shape of a {targets} pipeline's build graph, weighted by last build times.
# Answers: how much can parallel workers help, and which chain bounds wall time?
# Usage (from the project root):
#   Rscript tar_dag.R [script=_targets.R] [store=_targets] [n=15] [workers=<1,2,4,8 up to cores, and cores>] [outdated=FALSE] [overhead=0]
# workers: predict wall time for each worker count (list scheduling on the DAG,
#   branches as separate tasks, longest-remaining-path first).
# outdated=TRUE: predict only what tar_make() would rebuild now (tar_outdated()).
# overhead: seconds added per dispatched task (worker dispatch and data loading).
# Predictions reuse last build times; targets never built before count as 0 s and are listed.
# Read-only: tar_network(), tar_outdated(), tar_meta(); never builds anything. MB = bytes / 1e6.

args <- commandArgs(trailingOnly = TRUE)
kv <- function(key, default) {
  hit <- grep(paste0("^", key, "="), args, value = TRUE)
  if (length(hit)) sub("^[^=]+=", "", hit[[1]]) else default
}
script <- kv("script", "_targets.R")
store <- kv("store", "_targets")
n_show <- as.integer(kv("n", "15"))
default_workers <- {
  nc <- if (requireNamespace("parallelly", quietly = TRUE)) parallelly::availableCores() else parallel::detectCores()
  nc <- if (is.na(nc) || nc < 1) 1L else as.integer(nc)
  w <- c(1, 2, 4, 8)
  paste(sort(unique(c(w[w <= nc], nc))), collapse = ",")
}
workers <- as.integer(strsplit(kv("workers", default_workers), ",")[[1]])
only_outdated <- toupper(kv("outdated", "FALSE")) == "TRUE"
overhead <- as.numeric(kv("overhead", "0"))

net <- targets::tar_network(script = script, store = store, targets_only = TRUE, outdated = FALSE)
meta <- targets::tar_meta(store = store, fields = c("name", "type", "parent", "seconds", "bytes", "children"), complete_only = FALSE)

# A pattern row's seconds already sum its current branches. Old branch rows stay
# in meta until tar_prune(), so keep only branches a pattern lists in `children`.
current <- unlist(meta$children[meta$type == "pattern"], use.names = FALSE)
branches <- meta[meta$type == "branch" & meta$name %in% current, ]
branch_sec <- tapply(branches$seconds, branches$parent, sum, na.rm = TRUE)
branch_n <- tapply(branches$seconds, branches$parent, length)
stems <- meta[meta$type != "branch", ]
sec <- setNames(stems$seconds, stems$name)
nodes <- net$vertices$name
w <- ifelse(is.na(sec[nodes]), 0, sec[nodes])
names(w) <- nodes
edges <- net$edges[net$edges$from %in% nodes & net$edges$to %in% nodes, ]

# Topological order (Kahn).
indeg <- setNames(integer(length(nodes)), nodes)
tab <- table(edges$to)
indeg[names(tab)] <- as.integer(tab)
children <- split(edges$to, factor(edges$from, levels = nodes))
parents <- split(edges$from, factor(edges$to, levels = nodes))
order <- character(0)
queue <- nodes[indeg == 0]
while (length(queue)) {
  v <- queue[[1]]
  queue <- queue[-1]
  order <- c(order, v)
  for (ch in children[[v]]) {
    indeg[[ch]] <- indeg[[ch]] - 1L
    if (indeg[[ch]] == 0L) queue <- c(queue, ch)
  }
}
if (length(order) < length(nodes)) stop("graph has a cycle or unparsed nodes")

# Depth (unweighted level) and earliest finish time (weighted longest path).
longest <- function(w) {
  finish <- setNames(numeric(length(nodes)), nodes)
  best_parent <- setNames(rep(NA_character_, length(nodes)), nodes)
  for (v in order) {
    ps <- parents[[v]]
    if (length(ps)) {
      k <- ps[which.max(finish[ps])]
      best_parent[[v]] <- k
      finish[[v]] <- finish[[k]] + w[[v]]
    } else {
      finish[[v]] <- w[[v]]
    }
  }
  path <- character(0)
  v <- names(which.max(finish))
  while (!is.na(v)) {
    path <- c(v, path)
    v <- best_parent[[v]]
  }
  list(finish = finish, path = path, crit = max(finish))
}
depth <- setNames(integer(length(nodes)), nodes)
for (v in order) if (length(parents[[v]])) depth[[v]] <- max(depth[parents[[v]]]) + 1L

# Two views of patterns: branches run one after another (one worker), or all
# at once (as many workers as branches, so only the longest branch counts).
w_par <- w
branch_max <- tapply(branches$seconds, branches$parent, max, na.rm = TRUE)
hit <- intersect(names(branch_max), nodes)
w_par[hit] <- branch_max[hit]
lp <- longest(w)
lp_par <- longest(w_par)
finish <- lp$finish
path <- lp$path
crit <- lp$crit
total <- sum(w)

width <- table(depth)
cat(sprintf("targets: %d  edges: %d  levels: %d  max width: %d (level %s)\n",
            length(nodes), nrow(edges), length(width), max(width), names(width)[which.max(width)]))
cat(sprintf("total seconds: %.1f  critical path: %.1f s  max useful speedup (total / critical): %.1fx\n",
            total, crit, if (crit > 0) total / crit else NA))
if (length(hit)) {
  cat(sprintf("with every dynamic branch in parallel: critical path %.1f s, max useful speedup %.1fx\n",
              lp_par$crit, total / lp_par$crit))
}
cat("  -> more workers than the speedup ratio cannot shorten the build; shorten the critical path instead.\n\n")

cat("critical path (seconds, cumulative):\n")
print(data.frame(target = path, seconds = round(w[path], 2), cumulative = round(finish[path], 1)), row.names = FALSE)

cat("\nwidth by level (targets that could run together if inputs were ready):\n")
lvl <- data.frame(level = as.integer(names(width)), n = as.integer(width),
                  seconds = round(as.numeric(tapply(w, depth, sum)[names(width)]), 1))
print(utils::head(lvl, 40), row.names = FALSE)

# Time-weighted parallelism: at each moment of an ideal schedule (infinite
# workers, every target starts as soon as its parents finish), how many run?
start <- finish - w
busy <- w > 0
if (any(busy)) {
  ev <- sort(unique(c(start[busy], finish[busy])))
  mids <- (head(ev, -1) + tail(ev, -1)) / 2
  running <- vapply(mids, \(t) sum(start[busy] <= t & finish[busy] > t), integer(1))
  dur <- diff(ev)
  q <- function(k) sum(dur[running >= k]) / sum(dur)
  cat(sprintf("\nideal schedule: peak concurrency %d; share of wall time with >=2 running %.0f%%, >=4 %.0f%%, >=8 %.0f%%\n",
              max(running), 100 * q(2), 100 * q(4), 100 * q(8)))
}

if (length(branch_sec)) {
  cat("\ndynamic branches (inner parallelism available to workers):\n")
  print(data.frame(pattern = names(branch_sec), branches = as.integer(branch_n[names(branch_sec)]),
                   seconds = round(as.numeric(branch_sec), 1),
                   median_branch_s = round(as.numeric(tapply(branches$seconds, branches$parent, median)[names(branch_sec)]), 3)),
        row.names = FALSE)
}

fan <- data.frame(target = nodes, MB = round(setNames(stems$bytes, stems$name)[nodes] / 1e6, 1),
                  downstream = lengths(children[nodes]))
fan <- fan[!is.na(fan$MB) & fan$downstream > 0, ]
fan <- fan[order(-fan$MB * fan$downstream), ]
cat("\nlarge objects by fan-out (MB x direct downstream targets, targets-only network, as in tar_profile.R;\n",
    " each downstream target loads it unless memory is persistent or shared; tar_profile.R also counts loads per branch):\n", sep = "")
print(utils::head(fan, n_show), row.names = FALSE)

# Predicted wall time ----
todo <- if (only_outdated) {
  targets::tar_outdated(script = script, store = store, targets_only = TRUE, branches = FALSE, reporter = "silent")
} else nodes
todo <- intersect(todo, nodes)
unknown <- todo[is.na(sec[todo])]

# Tasks: one per stem; one per current branch for patterns.
task_parent <- character(0)
task_sec <- numeric(0)
for (v in nodes) {
  if (!v %in% todo) next
  bs <- branches$seconds[branches$parent == v]
  if (length(bs)) {
    task_parent <- c(task_parent, rep(v, length(bs)))
    task_sec <- c(task_sec, bs)
  } else {
    task_parent <- c(task_parent, v)
    task_sec <- c(task_sec, ifelse(is.na(sec[v]), 0, sec[[v]]))
  }
}
task_sec <- ifelse(is.na(task_sec), 0, task_sec) + overhead

# Priority: longest remaining path below each node (branches-parallel view).
bottom <- setNames(numeric(length(nodes)), nodes)
for (v in rev(order)) {
  ch <- children[[v]]
  own <- if (v %in% todo) w_par[[v]] else 0
  bottom[[v]] <- own + if (length(ch)) max(bottom[ch]) else 0
}

simulate <- function(k) {
  remaining <- table(factor(task_parent, levels = nodes))
  done <- setNames(!(nodes %in% todo), nodes)
  started <- rep(FALSE, length(task_sec))
  free_at <- numeric(k)
  running_end <- numeric(0)
  running_task <- integer(0)
  t <- 0
  repeat {
    ready_nodes <- nodes[!done & vapply(parents[nodes], \(ps) all(done[ps]), logical(1))]
    ready <- which(!started & task_parent %in% ready_nodes)
    ready <- ready[order(-bottom[task_parent[ready]])]
    idle <- k - length(running_task)
    if (idle > 0 && length(ready)) {
      go <- head(ready, idle)
      started[go] <- TRUE
      running_task <- c(running_task, go)
      running_end <- c(running_end, t + task_sec[go])
      next
    }
    if (!length(running_task)) break
    i <- which.min(running_end)
    t <- running_end[[i]]
    v <- task_parent[[running_task[[i]]]]
    running_task <- running_task[-i]
    running_end <- running_end[-i]
    remaining[[v]] <- remaining[[v]] - 1L
    if (remaining[[v]] == 0L) done[[v]] <- TRUE
  }
  t
}

if (!length(task_sec)) {
  cat("\npredicted wall time: nothing to build (all targets up to date)\n")
  quit(save = "no")
}
cat(sprintf("\npredicted wall time (%s; %d tasks; overhead %.2f s/task):\n",
            if (only_outdated) "outdated targets only" else "full rebuild", length(task_sec), overhead))
pred <- data.frame(workers = workers, seconds = vapply(workers, simulate, numeric(1)))
pred$speedup <- ifelse(pred$seconds > 0, round(pred$seconds[1] / pred$seconds, 2), NA)
pred$seconds <- round(pred$seconds, 1)
print(pred, row.names = FALSE)
if (length(unknown)) cat("no previous build time (counted as 0 s):", paste(head(unknown, 20), collapse = ", "), "\n")
cat("Assumes each target takes its last build time and workers are free to start; excludes",
    "worker startup, data transfer to workers and memory limits. Compare with the real run.\n")
