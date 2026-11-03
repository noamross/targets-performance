# Run benchmark scripts listed in suite.csv, one at a time, each under a memory
# cap that covers the script's process tree and any R workers it starts
# (crew/mirai daemons detach from the tree). Works on Linux, macOS and Windows.
# Usage (from bench/):
#   Rscript run_suite.R [suite=suite.csv] [ci=TRUE] [topics=fastfns,storage] [scripts=a.R,b.R]
#                       [skip_needs=network,docker] [cap_gb=] [timeout_min=30] [log=ci/run_log.csv] [dry=FALSE]
# ci=TRUE runs only rows with ci == TRUE. Each script writes its own results CSV.
# Exit status per script: 0 ok, 137 killed over the memory cap, 124 killed at timeout_min,
# -1 skipped (machine below min_cores / min_ram_gb in suite.csv, or needs unix on Windows;
# the log row's `reason` says why). Skipped rows do not count as failed.

args <- commandArgs(trailingOnly = TRUE)
kv <- function(key, default) {
  hit <- grep(paste0("^", key, "="), args, value = TRUE)
  if (length(hit)) sub("^[^=]+=", "", hit[[1]]) else default
}
split_arg <- function(x) {
  if (is.na(x) || !nzchar(x)) character(0) else strsplit(x, ",")[[1]]
}

suite <- utils::read.csv(kv("suite", "suite.csv"), stringsAsFactors = FALSE)
if (toupper(kv("ci", "FALSE")) == "TRUE") {
  suite <- suite[suite$ci, ]
}
topics <- split_arg(kv("topics", NA))
if (length(topics)) {
  suite <- suite[suite$topic %in% topics, ]
}
scripts <- split_arg(kv("scripts", NA))
if (length(scripts)) {
  suite <- suite[suite$script %in% scripts, ]
}
skip <- split_arg(kv("skip_needs", NA))
needs <- strsplit(ifelse(is.na(suite$needs), "", suite$needs), ";")
if (length(skip)) {
  suite <- suite[!vapply(needs, \(n) any(n %in% skip), logical(1)), ]
}
for (col in c("min_cores", "min_ram_gb")) {
  if (!col %in% names(suite)) suite[[col]] <- NA_real_
}
my_cores <- {
  n <- if (requireNamespace("parallelly", quietly = TRUE)) parallelly::availableCores() else parallel::detectCores()
  n <- as.integer(n)
  if (is.na(n) || n < 1L) 1L else n
}
my_ram_gb <- ps::ps_system_memory()$total / 2^30
skip_reason <- function(row) {
  nd <- strsplit(if (is.na(row$needs)) "" else row$needs, ";")[[1]]
  if (.Platform$OS.type == "windows" && "unix" %in% nd) return("needs unix")
  if (!is.na(row$min_cores) && my_cores < row$min_cores) {
    return(sprintf("needs %g cores, have %d", row$min_cores, my_cores))
  }
  if (!is.na(row$min_ram_gb) && my_ram_gb < row$min_ram_gb) {
    return(sprintf("needs %g GB RAM, have %.1f", row$min_ram_gb, my_ram_gb))
  }
  ""
}
log_file <- kv("log", file.path("ci", "run_log.csv"))
cap_override <- as.numeric(kv("cap_gb", NA))
timeout_s <- as.numeric(kv("timeout_min", "30")) * 60
if (nrow(suite) == 0) {
  stop("no scripts selected", call. = FALSE)
}

cat(sprintf(
  "run_suite: %d scripts, estimated %.0f min\n",
  nrow(suite),
  sum(suite$est_min, na.rm = TRUE)
))
if (toupper(kv("dry", "FALSE")) == "TRUE") {
  suite$skip <- vapply(seq_len(nrow(suite)), \(i) skip_reason(suite[i, ]), "")
  print(
    suite[, c("script", "topic", "est_min", "cap_gb", "min_cores", "min_ram_gb", "needs", "skip")],
    row.names = FALSE
  )
  quit(save = "no")
}

# One benchmark at a time: refuse to start while another benchmark script runs.
hold <- file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), ".hold")
if (file.exists(hold) && Sys.getenv("BENCH_HOLD_OK") != "1") {
  stop("on hold (", paste(readLines(hold, warn = FALSE), collapse = " "), "); wait and retry", call. = FALSE)
}
others <- Filter(
  function(h) {
    cl <- tryCatch(paste(ps::ps_cmdline(h), collapse = " "), error = function(e) "")
    ps::ps_pid(h) != Sys.getpid() &&
      grepl("(^| )(fastfns|vectorize|storage|targets_mech|remote|startup|blas)/[^ ]+\\.R", cl)
  },
  ps::ps()$ps_handle
)
if (length(others) && Sys.getenv("BENCH_ALLOW_CONCURRENT") != "1") {
  stop("another benchmark is running (pid ", paste(vapply(others, ps::ps_pid, integer(1)), collapse = ", "), "); refusing to start", call. = FALSE)
}

rscript <- file.path(
  R.home("bin"),
  if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
)
is_r <- function(p) {
  nm <- tryCatch(ps::ps_name(p), error = function(e) "")
  grepl("^(R|Rterm|Rscript)(\\.exe)?$", nm) || nm == "exec/R"
}
before <- vapply(Filter(is_r, ps::ps()$ps_handle), ps::ps_pid, integer(1))

tree_rss <- function(proc, t0) {
  root <- proc$as_ps_handle()
  kids <- tryCatch(
    ps::ps_children(root, recursive = TRUE),
    error = function(e) list()
  )
  # R processes started after this script did (detached workers)
  later <- Filter(
    function(h) {
      ok <- tryCatch(
        is_r(h) && !(ps::ps_pid(h) %in% before) && ps::ps_create_time(h) >= t0,
        error = function(e) FALSE
      )
      isTRUE(ok)
    },
    ps::ps()$ps_handle
  )
  hs <- c(list(root), kids, later)
  hs <- hs[!duplicated(vapply(hs, ps::ps_pid, integer(1)))]
  rss <- sum(vapply(
    hs,
    function(h) tryCatch(ps::ps_memory_info(h)[["rss"]], error = function(e) 0),
    numeric(1)
  ))
  list(rss = rss, handles = hs)
}

avail <- ps::ps_system_memory()$avail
write_log <- function(row, status, secs, peak_mb, cap_mb, killed, reason) {
  # Appended after each script so a job timeout still leaves a log.
  log_row <- data.frame(
    script = row$script,
    topic = row$topic,
    status = status,
    seconds = round(secs),
    peak_mb = round(peak_mb),
    cap_mb = round(cap_mb),
    killed = killed,
    machine = Sys.getenv(
      "BENCH_ENV_LABEL",
      paste(Sys.info()[["sysname"]], Sys.info()[["machine"]])
    ),
    run_date = format(Sys.Date()),
    reason = reason
  )
  utils::write.table(
    log_row,
    log_file,
    sep = ",",
    row.names = FALSE,
    qmethod = "double",
    col.names = !file.exists(log_file),
    append = file.exists(log_file)
  )
}
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
unlink(log_file)
statuses <- integer(0)
for (i in seq_len(nrow(suite))) {
  row <- suite[i, ]
  reason <- skip_reason(row)
  if (nzchar(reason)) {
    cat(sprintf("[%d/%d] %s SKIPPED: %s\n", i, nrow(suite), row$script, reason))
    write_log(row, -1L, 0, 0, 0, "", reason)
    statuses <- c(statuses, -1L)
    next
  }
  cap_gb <- if (!is.na(cap_override)) {
    cap_override
  } else if (!is.na(row$cap_gb)) {
    row$cap_gb
  } else {
    4
  }
  cap <- min(cap_gb * 2^30, avail * 0.6)
  # suite.csv separates a script's positional args with ";"
  sargs <- if (is.na(row$args) || !nzchar(row$args)) {
    character(0)
  } else {
    strsplit(row$args, ";")[[1]]
  }
  cat(sprintf(
    "[%d/%d] %s (cap %.1f GB, est %s min)\n",
    i,
    nrow(suite),
    row$script,
    cap / 2^30,
    row$est_min
  ))
  t0 <- Sys.time()
  out_file <- file.path(
    "ci",
    "logs",
    paste0(sub("\\.R$", "", gsub("/", "__", row$script)),
           if (!is.na(row$args) && nzchar(row$args)) paste0("_", gsub("[^A-Za-z0-9.]+", "-", row$args)), ".log")
  )
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  proc <- processx::process$new(
    rscript,
    c(row$script, sargs),
    stdout = out_file,
    stderr = "2>&1",
    env = c("current", BENCH_MEM_CAP_MB = as.character(round(cap / 2^20))),
    cleanup_tree = TRUE
  )
  start_ct <- ps::ps_create_time(proc$as_ps_handle())
  peak <- 0
  killed <- ""
  while (proc$is_alive()) {
    tr <- tree_rss(proc, start_ct)
    peak <- max(peak, tr$rss)
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (tr$rss > cap || elapsed > timeout_s) {
      killed <- if (tr$rss > cap) "memory" else "timeout"
      for (h in rev(tr$handles)) {
        try(ps::ps_kill(h), silent = TRUE)
      }
      break
    }
    Sys.sleep(1)
  }
  proc$wait(5000)
  status <- switch(
    killed,
    memory = 137L,
    timeout = 124L,
    proc$get_exit_status()
  )
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf(
    "    status %s, %.0f s, peak %.0f MB%s\n",
    status,
    secs,
    peak / 2^20,
    if (nzchar(killed)) paste0(" (KILLED: ", killed, ")") else ""
  ))
  write_log(row, status, secs, peak / 2^20, cap / 2^20, killed, "")
  statuses <- c(statuses, status)
}
failed <- sum(statuses > 0)
skipped <- sum(statuses < 0)
cat(sprintf(
  "run_suite: %d ok, %d failed, %d skipped; log %s\n",
  length(statuses) - failed - skipped,
  failed,
  skipped,
  log_file
))
quit(save = "no", status = if (failed) 1L else 0L)
