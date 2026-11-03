# Helpers for toy-pipeline benchmarks. Source from bench/: source("targets_mech/_tm.R")
source("_common.R")
SCRATCH <- bench_scratch("b4")
dir.create(SCRATCH, recursive = TRUE, showWarnings = FALSE)
TM_PKGS <- c("targets", "tarchetypes", "crew", "mori", "qs2", "dplyr", "data.table")

# Text of the common top of a toy _targets.R: helpers, controller, options.
# nproc > 1 (or crew = TRUE) -> crew_controller_local + deployment "worker"; else no controller, deployment "main".
tm_prelude <- function(nproc = 1, crew = nproc > 1, tasks_max = "Inf", seconds_idle = 300,
                       memory = "auto", storage = "worker", retrieval = "auto",
                       gc = 0, packages = NULL, deployment = NULL, extra_opts = NULL) {
  if (is.null(deployment)) deployment <- if (crew) "worker" else "main"
  opts <- c(sprintf('memory = "%s"', memory), sprintf('storage = "%s"', storage),
            sprintf('retrieval = "%s"', retrieval), sprintf("garbage_collection = %s", gc),
            sprintf('deployment = "%s"', deployment),
            if (!is.null(packages)) sprintf("packages = %s", paste(deparse(packages), collapse = "")),
            if (crew) sprintf("controller = crew::crew_controller_local(workers = %d, seconds_idle = %s, tasks_max = %s)",
                              nproc, seconds_idle, tasks_max),
            extra_opts)
  paste(c(
    "library(targets); library(tarchetypes)",
    "spin <- function(s) { t0 <- proc.time()[[1]]; x <- 0; while (proc.time()[[1]] - t0 < s) x <- x + sum(sqrt(runif(2000))); s }",
    "make_big <- function(mb) { n <- as.integer(mb * 1e6 / 8 / 10); set.seed(1); as.data.frame(matrix(runif(n * 10), ncol = 10, dimnames = list(NULL, paste0('x', 1:10)))) }",
    "consume <- function(big, i) { m <- as.matrix(big[, 1:3]); sum(m * 2) + i }",
    # qs2 format that logs every read/write (pid, seconds) to $TM_LOG
    "fmt_logged <- tar_format(",
    "  read = function(path) { t0 <- proc.time()[[3]]; x <- qs2::qs_read(path); cat(sprintf('R,%d,%.4f\\n', Sys.getpid(), proc.time()[[3]] - t0), file = Sys.getenv('TM_LOG'), append = TRUE); x },",
    "  write = function(object, path) { t0 <- proc.time()[[3]]; qs2::qs_save(object, path); cat(sprintf('W,%d,%.4f\\n', Sys.getpid(), proc.time()[[3]] - t0), file = Sys.getenv('TM_LOG'), append = TRUE); invisible() }",
    ")",
    sprintf("tar_option_set(%s)", paste(opts, collapse = ",\n  ")),
    ""), collapse = "\n")
}

# Worker counts used by the toy pipelines: the old fixed values, limited to the cores available.
NP3 <- np_cap(3); NP4 <- np_cap(4); NP6 <- np_cap(6)

# TRUE when a run expected to peak near est_mb fits the memory budget; else say so and skip.
tm_fits <- function(est_mb, what) {
  ok <- est_mb <= mem_budget_mb()
  if (!ok) message(sprintf("skipping %s: est. peak %.0f MB > budget %.0f MB", what, est_mb, mem_budget_mb()))
  ok
}

tm_libs <- function() {
  p <- .libPaths(); p <- p[dir.exists(p)]
  paste(normalizePath(p), collapse = .Platform$path.sep)
}

# Run tar_make `makes` times in a child Rscript inside a scratch store dir; sample RSS of the process tree.
# `after`: R code (string) run in the child after the makes (has `dir`, `res` list; add to res).
# `between`: R code run between makes (index `k` available). Returns a one-row-per-run data.frame via $runs + $res.
tm_run <- function(case, src, makes = 1L, after = "", between = "", keep = FALSE, env = character(), timeout = 900, names1 = "", make_args = "") {
  dir <- file.path(SCRATCH, case); unlink(dir, recursive = TRUE); dir.create(dir, recursive = TRUE)
  on.exit(if (!keep) unlink(dir, recursive = TRUE), add = TRUE)
  writeLines(src, file.path(dir, "_targets.R"))
  log <- file.path(dir, "tm.log"); file.create(log)
  writeLines(c(
    "library(targets)",
    sprintf("makes <- %d", makes),
    "res <- list(wall = numeric(), completed = integer(), skipped = integer())",
    "for (k in seq_len(makes)) {",
    "  if (k > 1) { Sys.setenv(TM_LOG = sub('tm.log', sprintf('tm%d.log', k), Sys.getenv('TM_LOG'))); file.create(Sys.getenv('TM_LOG')) }",
    "  nm <- Sys.getenv('TM_NAMES1')",
    "  extra <- eval(parse(text = paste0('list(', sub('^, ', '', Sys.getenv('TM_MAKE_ARGS')), ')')))",
    "  args <- c(list(reporter = 'silent'), extra); if (k == 1 && nzchar(nm)) args$names <- strsplit(nm, ',')[[1]]",
    "  res$wall[k] <- system.time(do.call(tar_make, args))[['elapsed']]",
    "  file.create(sprintf('make%d.done', k))",
    "  p <- do.call(tar_progress, if (!is.null(extra$store)) list(store = extra$store) else list()); res$completed[k] <- sum(p$progress == 'completed'); res$skipped[k] <- sum(p$progress == 'skipped')",
    "  if (k < makes) { dir <- getwd(); eval(parse(text = Sys.getenv('TM_BETWEEN'))) }",
    "}",
    "m <- do.call(tar_meta, c(list(fields = c('name', 'type', 'seconds', 'bytes', 'warnings', 'error')), if (!is.null(extra$store)) list(store = extra$store)))",
    "res$meta <- as.data.frame(m)",
    "dir <- getwd()",
    "eval(parse(text = Sys.getenv('TM_AFTER')))",
    "saveRDS(res, 'res.rds')"), file.path(dir, "run.R"))
  p <- processx::process$new(rscript_bin(), "run.R", wd = dir,
                             env = c("current", R_LIBS = tm_libs(), TM_LOG = log, TM_AFTER = after, TM_BETWEEN = between, TM_NAMES1 = names1, TM_MAKE_ARGS = if (nzchar(make_args)) paste0(", ", make_args) else "", env),
                             stdout = file.path(dir, "out.txt"), stderr = "2>&1")
  base_avail <- ps::ps_system_memory()$avail / 2^20
  peak <- 0; peak_by <- numeric(20); min_avail <- base_avail; t0 <- Sys.time()
  child_ct <- ps::ps_create_time(p$as_ps_handle())
  # Below the outer cap (run_suite.R counts this harness too), so the case is recorded as capped and the script continues
  inner_cap <- (mem_budget_mb() - ps::ps_memory_info()[["rss"]] / 2^20) * 0.9
  while (p$is_alive()) {
    kids <- tryCatch(ps::ps_children(p$as_ps_handle(), recursive = TRUE), error = function(e) list())
    # crew/mirai workers detach from the tree: also count R processes started after the child
    later <- Filter(function(h) isTRUE(tryCatch(
      grepl("^(R|Rterm|Rscript)(\\.exe)?$", ps::ps_name(h)) && ps::ps_create_time(h) >= child_ct, error = function(e) FALSE)),
      ps::ps()$ps_handle)
    hs <- c(list(p$as_ps_handle()), kids, later)
    hs <- hs[!duplicated(vapply(hs, function(h) tryCatch(ps::ps_pid(h), error = function(e) NA_integer_), 0L))]
    rss <- sum(vapply(hs, function(h)
      tryCatch(ps::ps_memory_info(h)[["rss"]], error = function(e) 0), 0)) / 2^20
    peak <- max(peak, rss); ph <- min(20, length(list.files(dir, "^make[0-9]+.done$")) + 1L); peak_by[ph] <- max(peak_by[ph], rss)
    min_avail <- min(min_avail, ps::ps_system_memory()$avail / 2^20)
    if (rss > inner_cap) {
      p$kill_tree(); for (h in later) try(ps::ps_kill(h), silent = TRUE)
      message(sprintf("  RSS %.0f MB over cap %.0f MB; killed (recorded as capped)", rss, inner_cap))
      return(list(wall = NA_real_, completed = NA_integer_, skipped = NA_integer_, sum_meta_s = NA_real_, errors = NA_integer_,
                  n_targets = NA_integer_, loads = NA_integer_, load_s = NA_real_, writes = NA_integer_, write_s = NA_real_,
                  peak_rss_mb = peak, sys_peak_mb = base_avail - min_avail, total_s = NA_real_, capped = TRUE))
    }
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout) { p$kill_tree(); stop("timeout") }
    Sys.sleep(0.1)
  }
  total <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (!file.exists(file.path(dir, "res.rds"))) stop("run failed:\n", paste(utils::tail(readLines(file.path(dir, "out.txt")), 20), collapse = "\n"))
  res <- readRDS(file.path(dir, "res.rds"))
  m <- res$meta
  res$sum_meta_s <- sum(m$seconds[m$type %in% c("stem", "branch")], na.rm = TRUE)
  res$errors <- sum(!is.na(m$error) & nzchar(m$error)); res$warnings <- sum(!is.na(m$warnings) & nzchar(m$warnings))
  res$n_targets <- sum(m$type %in% c("stem", "branch"))
  lg <- utils::read.csv(log, header = FALSE, col.names = c("op", "pid", "s"))
  res$loads <- sum(lg$op == "R"); res$load_s <- sum(lg$s[lg$op == "R"])
  res$writes <- sum(lg$op == "W"); res$write_s <- sum(lg$s[lg$op == "W"])
  res$ops <- paste(vapply(sort(list.files(dir, "^tm[0-9]*\\.log$", full.names = TRUE)), function(f) {
    l <- utils::read.csv(f, header = FALSE, col.names = c("op", "pid", "s")); paste(paste0(names(table(l$op)), "=", table(l$op)), collapse = " ") }, ""), collapse = " | make: ")
  res$peak_by_make <- peak_by[seq_len(makes)]
  res$peak_rss_mb <- peak; res$sys_peak_mb <- base_avail - min_avail; res$total_s <- total
  res$dir <- dir
  res
}

# One CSV row from tm_run output (first make only unless `k` given).
tm_row <- function(task, n, method, r, k = 1L, notes = "") {
  data.frame(topic = "targets_mech", task = task, n = n, method = method,
             wall_s = r$wall[k], sum_meta_s = r$sum_meta_s, n_targets = r$n_targets,
             completed = r$completed[k], skipped = r$skipped[k],
             loads = r$loads, load_s = r$load_s, writes = r$writes, write_s = r$write_s,
             peak_rss_mb = r$peak_rss_mb, sys_peak_mb = r$sys_peak_mb, errors = r$errors,
             notes = paste0(notes, if (isTRUE(r$capped)) " KILLED at memory cap (peak is a lower bound)" else ""), packages = pkg_versions(c("targets", "crew", "tarchetypes", "mori", "qs2")),
             stringsAsFactors = FALSE)
}
tm_save <- function(rows, file) { rows <- cbind(rows, bench_env()); write_result(rows, file); print(rows[, c("task", "n", "method", "wall_s", "sum_meta_s", "loads", "load_s", "peak_rss_mb", "sys_peak_mb")]); invisible(rows) }
