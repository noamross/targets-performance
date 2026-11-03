# Case 5: mori-shared big target (skills/targets-performance/scripts/formats.R) vs no mori; guard test; anti-pattern.
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c5_mori.csv"
FMT <- normalizePath("../skills/targets-performance/scripts/formats.R")
rows <- list(); notes_txt <- character()
add <- function(...) rows[[length(rows) + 1]] <<- tm_row(...)
cons <- 'cons <- lapply(1:6, function(i) tar_target_raw(paste0("c", i), substitute({ spin(1); consume(big, I) }, list(I = i)), format = "rds", retrieval = "main"))'

# (a) wall + peak RSS: NPROC=3, 6 consumers
pipe_a <- function(mb, kind) {
  pre <- tm_prelude(NP3, memory = "persistent", retrieval = if (kind == "default") "worker" else "main")
  big <- switch(kind,
    default = sprintf('tar_target(big, make_big(%d), format = format_qs_unshared, memory = "auto")', mb),
    nomori_main = sprintf('tar_target(big, make_big(%d), format = format_qs_unshared, memory = "persistent", deployment = "main", storage = "main", retrieval = "main")', mb),
    mori_main = sprintf('tar_target(big, mori::share(make_big(%d)), format = format_qs_shared, memory = "persistent", deployment = "main", storage = "main", retrieval = "main")', mb))
  paste(pre, sprintf('source("%s")', FMT), cons, sprintf("c(list(%s), cons)", big), sep = "\n")
}
for (mb in c(100, 300)) for (kind in c("default", "nomori_main", "mori_main")) {
  message("a: ", mb, " ", kind)
  if (!tm_fits(mb * (2 + 2 * NP3), sprintf("c5 a %g MB", mb))) next
  r <- tm_run("c5a", pipe_a(mb, kind), makes = if (kind == "mori_main") 2 else 1)
  add(sprintf("a_big%d_nproc%d", mb, NP3), mb, switch(kind, default = "no mori, worker retrieval", nomori_main = "no mori, main retrieval (qs2)", mori_main = "mori format_qs_shared, main retrieval"), r,
      notes = sprintf("6 consumers (spin 1 s + 90 MB matrix); NPROC=%d; tree RSS double-counts shared pages (see sys_peak_mb)", NP3))
  if (kind == "mori_main" && !isTRUE(r$capped)) {
    # (b) second make: everything up to date
    add(sprintf("b_rerun_big%d", mb), mb, "mori format_qs_shared: 2nd tar_make", r, k = 2,
        notes = sprintf("2nd make: completed=%d skipped=%d (up to date = skipped all)", r$completed[2], r$skipped[2]))
  }
}

# (c) guard: consumer returns mutate(big, z = 1); read in fresh session
pipe_c <- paste(tm_prelude(NP3, memory = "persistent", retrieval = "main"), sprintf('source("%s")', FMT), '
list(tar_target(big, mori::share(make_big(20)), format = format_qs_shared, memory = "persistent", deployment = "main", storage = "main", retrieval = "main"),
  tar_target(mut_unguarded, dplyr::mutate(big, z = 1), format = "rds"),
  tar_target(mut_guarded, dplyr::mutate(big, z = 1), format = format_qs_unshared),
  tar_target(mut_bare_qs2, dplyr::mutate(big, z = 1), format = tar_format(read = function(path) qs2::qs_read(path), write = function(object, path) qs2::qs_save(object, path))))', sep = "\n")
after_c <- '
rd <- function(nm) tryCatch(callr::r(function(nm) { x <- targets::tar_read_raw(nm); c(ok = sum(x$z) + nrow(x)) }, list(nm), libpath = .libPaths()), error = function(e) sub("\\\\s+", " ", conditionMessage(e)))
res$read_unguarded_rds <- rd("mut_unguarded"); res$read_bare_qs2 <- rd("mut_bare_qs2"); res$read_guarded <- rd("mut_guarded")
res$shared_cols <- NA'
r <- tm_run("c5c", pipe_c, after = after_c)
fmt1 <- function(x) paste(substr(as.character(unlist(x)), 1, 140), collapse = " / ")
add("c_guard", 20, "mutate(big,z=1) result read in fresh session", r, notes = sprintf("rds: [%s]; bare qs2 write: [%s]; format_qs_unshared: [%s]", fmt1(r$read_unguarded_rds), fmt1(r$read_bare_qs2), fmt1(r$read_guarded)))

# (d) anti-pattern: share() target with cue always
pipe_d <- function(mem) paste(tm_prelude(NP3, retrieval = "main"), sprintf('
list(tar_target(raw, make_big(20), format = "rds"),
  tar_target(shared, mori::share(raw), cue = tar_cue("always"), format = "rds", deployment = "main", memory = "%s"),
  tar_target(d1, sum(shared$x1)), tar_target(d2, sum(shared$x2)), tar_target(d3, sum(shared$x3)))', mem), sep = "\n")
r <- tryCatch(tm_run("c5d", pipe_d("transient"), makes = 1), error = function(e) conditionMessage(e))
if (is.character(r)) {
  msg <- paste(gsub("\\s+", " ", utils::tail(strsplit(r, "\n")[[1]], 4)), collapse = " ")
  rows[[length(rows) + 1]] <- data.frame(topic = "targets_mech", task = "d_antipattern", n = 20, method = "share() target cue always, memory=transient (default-like)",
    wall_s = NA, sum_meta_s = NA, n_targets = NA, completed = NA, skipped = NA, loads = NA, load_s = NA, writes = NA, write_s = NA, peak_rss_mb = NA, sys_peak_mb = NA, errors = NA,
    notes = paste("FAILED in the first tar_make:", msg), packages = pkg_versions(c("targets", "mori")))
}
r <- tm_run("c5d", pipe_d("persistent"), makes = 3, after = 'res$read_shared <- tryCatch(callr::r(function() nrow(targets::tar_read(shared)), libpath = .libPaths()), error = function(e) conditionMessage(e))')
add("d_antipattern", 20, "share() target cue always, memory=persistent", r, k = 1,
    notes = sprintf("completed per make (5 targets): %s ; skipped %s; tar_read(shared) in fresh session: %s", paste(r$completed, collapse = ","), paste(r$skipped, collapse = ","), fmt1(r$read_shared)))

# (e) parquet formats
pipe_e <- paste(tm_prelude(NP3, memory = "persistent", retrieval = "main"), sprintf('source("%s")', FMT), '
list(tar_target(pq, mori::share(make_big(20)), format = format_parquet_shared, memory = "persistent", deployment = "main", storage = "main", retrieval = "main"),
  tar_target(pq_c, c(mori::is_shared(pq), nrow(pq)), format = "rds", retrieval = "main"),
  tar_target(pq_mut, dplyr::mutate(pq, z = 1), format = format_parquet_unshared))', sep = "\n")
r <- tm_run("c5e", pipe_e, makes = 2, between = "tar_invalidate(pq_c)", after = '
res$pq_c <- tar_read(pq_c)
n <- as.integer(20 * 1e6 / 8 / 10); set.seed(1); ref <- as.data.frame(matrix(runif(n * 10), ncol = 10, dimnames = list(NULL, paste0("x", 1:10))))
res$same <- tryCatch(callr::r(function(ref) isTRUE(all.equal(as.data.frame(targets::tar_read(pq)), ref)), list(ref), libpath = .libPaths()), error = function(e) conditionMessage(e))
res$same_mut <- tryCatch(callr::r(function() sum(targets::tar_read(pq_mut)$z), libpath = .libPaths()), error = function(e) conditionMessage(e))',
 )
add("e_parquet", 20, "format_parquet_shared / unshared", r, notes = sprintf("consumer sees shared=%s nrow=%s (2nd make, read path); fresh-session read all.equal=%s; mutate result sum(z)=%s", paste(r$pq_c[1], collapse = ""), r$pq_c[2], fmt1(r$same), fmt1(r$same_mut)))
tm_save(do.call(rbind, rows), OUT)
