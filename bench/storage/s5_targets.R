source("storage/_storage.R")
if (!fits(160, 6)) { message("skipping s5: memory budget too small"); quit(save = "no") }
S5 <- file.path(SCRATCH, "s5"); unlink(S5, recursive = TRUE); dir.create(S5)
MT <- bench_cores() >= 4  # the 4-thread qs variants need 4 cores
if (!MT) message("skipping sav_qs4 variants: fewer than 4 cores")
VARS <- c("qs", if (MT) c("qs4", "qs4_l1"), "rds", "np", "fmt_np")
mk_src <- paste(c("library(targets); library(tarchetypes)",
  paste("make_b <-", paste(deparse(make_b), collapse = "\n")),
  'tar_option_set(packages = c("tibble"))',
  "list(",
  "  tar_target(base, make_b(2e5L), format = 'qs'),",
  "  tar_target(noop, 1L),",
  "  tar_target(sav_qs, identity(base), format = 'qs'),",
  if (MT) "  tar_target(sav_qs4, identity(base), format = 'qs', resources = tar_resources(qs = tar_resources_qs(nthreads = 4L))),",
  if (MT) "  tar_target(sav_qs4_l1, identity(base), format = 'qs', resources = tar_resources(qs = tar_resources_qs(nthreads = 4L, compress_level = 1L))),",
  "  tar_target(sav_rds, identity(base), format = 'rds'),",
  "  tar_nanoparquet(sav_np, identity(base)),",
  "  tar_target(sav_fmt_np, identity(base), format = tar_format_nanoparquet(compression = 'zstd')),",
  paste0("  tar_target(d_qs, nrow(sav_qs)), ", if (MT) "tar_target(d_qs4, nrow(sav_qs4)), tar_target(d_qs4_l1, nrow(sav_qs4_l1)), ", "tar_target(d_rds, nrow(sav_rds)),"),
  "  tar_target(d_np, nrow(sav_np)), tar_target(d_fmt_np, nrow(sav_fmt_np))",
  ")"), collapse = "\n")
writeLines(mk_src, file.path(S5, "_targets.R"))
writeLines(c('library(targets)',
  'tm <- function(nm) system.time(tar_make(names = all_of(nm), callr_function = NULL, reporter = "silent"))[["elapsed"]]',
  'out <- list(); out$base <- tm("base"); out$noop <- tm("noop")',
  sprintf('vars <- %s', paste(deparse(VARS), collapse = "")),
  'for (s in vars) out[[paste0("sav_", s)]] <- tm(paste0("sav_", s))',
  'for (s in vars) out[[paste0("d_", s)]] <- tm(paste0("d_", s))',
  'rd <- sapply(vars, function(s) system.time(tar_read_raw(paste0("sav_", s)))[["elapsed"]])',
  'm <- tar_meta(fields = c("seconds", "bytes", "format"), complete_only = TRUE)',
  'saveRDS(list(wall = unlist(out), read = rd, meta = as.data.frame(m)), "res.rds")'), file.path(S5, "run.R"))
processx::run(rscript_bin(), "run.R", wd = S5, echo = TRUE, stderr_to_stdout = TRUE,
              env = c("current", R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)))
r <- readRDS(file.path(S5, "res.rds"))
print(r$meta); print(r$wall); print(r$read)
m <- r$meta; m <- m[m$name != "base", ]
rows <- data.frame(topic = "storage", task = "b_targets_store", n = 2e5, method = m$name, seconds_meta = m$seconds, bytes_meta = m$bytes,
  wall_tar_make_s = unname(r$wall[m$name]), tar_read_s = unname(r$read[sub("^sav_", "", m$name)]),
  notes = "tar_meta seconds/bytes; wall = tar_make(names=) elapsed incl. startup; tar_read_s only for sav_*; d_* = nrow(sav_*) so wall includes load")
rows <- cbind(rows, bench_env()); write_result(rows, "storage/results/targets_store.csv"); print(rows[, 1:8])
unlink(S5, recursive = TRUE)
