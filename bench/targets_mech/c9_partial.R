# Case 9: partial loading of an already stored target with retrieval = "none" (+ path to the store file).
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c9_partial.csv"
rows <- list(); add <- function(...) rows[[length(rows) + 1]] <<- tm_row(...)
g <- function(x, d = 2) if (is.null(x) || !length(x)) "NA" else paste(round(x, d), collapse = "/")
fmt1 <- function(x) gsub("[[:space:]]+", " ", paste(as.character(unlist(x)), collapse = " "))
SECS <- 'res$sub_s <- res$meta$seconds[grepl("^sub", res$meta$name)]; res$big_s <- res$meta$seconds[res$meta$name %in% c("big", "big_path")]; res$big_bytes <- res$meta$bytes[res$meta$name %in% c("big", "big_path")]; res$store_kb <- sum(file.size(list.files("_targets/objects", full.names = TRUE, recursive = TRUE))) / 1024'
nonesub <- function(expr, ret = "none") sprintf('tar_target(sub, %s, retrieval = "%s")', expr, ret)

# ---- (a) dependency detection (20 MB, parquet format via tarchetypes nanoparquet format)
rd <- 'nanoparquet::read_parquet(tar_path_target(big), col_select = c("x1", "x2"))'
variants_a <- list(
  "path via tar_path_target(big) symbol" = sprintf('tar_target(sub, { p <- tar_path_target(big); c(exists("big"), nrow(%s)) }, retrieval = "none")', rd),
  "if (FALSE) big" = sprintf('tar_target(sub, { if (FALSE) big; p <- tar_path_target(big); c(exists("big"), nrow(%s)) }, retrieval = "none")', rd),
  "tar_target_raw(deps = 'big')" = sprintf('tar_target_raw("sub", quote({ p <- targets::tar_path_target("big"); c(exists("big"), nrow(nanoparquet::read_parquet(p, col_select = c("x1", "x2")))) }), deps = "big", retrieval = "none")'),
  "tar_read(big) in command (loads all)" = 'tar_target(sub, { b <- tar_read(big); c(exists("big"), nrow(b)) }, retrieval = "none")',
  "path string only (undeclared)" = 'tar_target(sub, { p <- "_targets/objects/big"; c(exists("big"), nrow(nanoparquet::read_parquet(p, col_select = c("x1", "x2")))) }, retrieval = "none")')
for (v in names(variants_a)) {
  src <- paste(tm_prelude(1), 'list(tar_target(big, make_big(5), format = tarchetypes::tar_format_nanoparquet()), ', variants_a[[v]], ")", sep = "\n")
  r <- tryCatch(tm_run("c9a", src, makes = 2, keep = FALSE,
      between = 'res$edges <- paste(capture.output(print(tar_network(targets_only = TRUE, reporter = "silent")$edges)), collapse = " "); res$sub1 <- tryCatch(tar_read(sub), error = function(e) NA); res$time1 <- tar_meta(sub)$time; txt <- readLines("_targets.R"); writeLines(sub("make_big(5)", "make_big(6)", txt, fixed = TRUE), "_targets.R"); res$outdated <- paste(tar_outdated(), collapse = ",")',
      after = 'res$sub2 <- tryCatch(tar_read(sub), error = function(e) NA); res$time2 <- tar_meta(sub)$time; res$reran <- res$time2 > res$time1'), error = function(e) conditionMessage(e))
  if (is.character(r)) { rows[[length(rows) + 1]] <- data.frame(topic = "targets_mech", task = "a_dependency", n = 5, method = v, wall_s = NA, notes = paste("run failed:", fmt1(utils::tail(strsplit(r, "\n")[[1]], 5))), packages = "", stringsAsFactors = FALSE)
    cat("a:", v, "FAILED\n"); next }
  add("a_dependency", 5, v, r, notes = sprintf("edges big->sub: %s; sub value (exists(big), nrow): %s; after changing big's command: tar_outdated = [%s], sub re-ran in make 2: %s; sub value after: %s", grepl("big", r$edges) && grepl("sub", r$edges), fmt1(r$sub1), r$outdated, r$reran, fmt1(r$sub2)))
}

# ---- (b) peak RSS and wall: serial, 300 MB big built in make 1 (names = big), consumer in make 2
MB <- 300
cols2 <- 'c("x1", "x2")'
pq <- 'format = tarchetypes::tar_format_nanoparquet()'
mkb <- function(expr, ret = "worker", bigfmt = pq, big = sprintf("tar_target(big, make_big(%d), %s)", MB, bigfmt), np = 1, plc = "worker") {
  paste(tm_prelude(np, storage = plc), sprintf('list(%s, tar_target(sub, %s, retrieval = "%s"))', big, expr, ret), sep = "\n")
}
P <- 'tar_path_target(big)'
cases_b <- list(
  list("normal retrieval, then subset 2 cols (nanoparquet format)", mkb('{ s <- big[, c("x1", "x2")]; colSums(s) }')),
  list("retrieval none + nanoparquet col_select 2 cols", mkb(sprintf('{ s <- nanoparquet::read_parquet(%s, col_select = %s); colSums(s) }', P, cols2), "none")),
  list("retrieval none + arrow open_dataset select 2 cols", mkb(sprintf('{ s <- dplyr::collect(dplyr::select(arrow::open_dataset(%s), x1, x2)); colSums(s) }', P), "none")),
  list("retrieval none + duckdb sum(x1),sum(x2)", mkb(sprintf('{ con <- DBI::dbConnect(duckdb::duckdb()); on.exit(DBI::dbDisconnect(con, shutdown = TRUE)); unlist(DBI::dbGetQuery(con, sprintf("SELECT sum(x1) a, sum(x2) b FROM read_parquet(\'%%s\')", %s))) }', P), "none")),
  list("normal retrieval, then filter x1 < 0.01 (1% rows)", mkb('{ s <- big[big$x1 < 0.01, ]; c(nrow(s), sum(s$x2)) }')),
  list("retrieval none + arrow filter x1 < 0.01", mkb(sprintf('{ s <- dplyr::collect(dplyr::filter(arrow::open_dataset(%s), x1 < 0.01)); c(nrow(s), sum(s$x2)) }', P), "none")),
  list("retrieval none + duckdb filter x1 < 0.01", mkb(sprintf('{ con <- DBI::dbConnect(duckdb::duckdb()); on.exit(DBI::dbDisconnect(con, shutdown = TRUE)); unlist(DBI::dbGetQuery(con, sprintf("SELECT count(*) n, sum(x2) s FROM read_parquet(\'%%s\') WHERE x1 < 0.01", %s))) }', P), "none")),
  list("qs2 format big: normal retrieval then subset", mkb('{ s <- big[, c("x1", "x2")]; colSums(s) }', bigfmt = "format = fmt_logged")),
  list("qs2 format big: retrieval none + qs2::qs_read whole then subset", mkb(sprintf('{ s <- qs2::qs_read(%s)[, c("x1", "x2")]; colSums(s) }', P), "none", bigfmt = "format = fmt_logged")))
for (cc in cases_b) {
  message("b: ", cc[[1]])
  if (!tm_fits(MB * 4, "c9 b")) next
  r <- tryCatch(tm_run("c9b", cc[[2]], makes = 2, names1 = "big", after = SECS), error = function(e) { message(conditionMessage(e)); NULL })
  if (!is.null(r)) { if (!isTRUE(r$capped)) r$peak_rss_mb <- r$peak_by_make[2]; add("b_serial_300MB", 300, cc[[1]], r, k = 2, notes = sprintf("consumer make only: wall(make 2) incl. callr start; sub target seconds %s; big build seconds %s; big store bytes %s MB; peak RSS of make 2", g(r$sub_s), g(r$big_s, 1), g(r$big_bytes / 1e6, 0))) }
}

# ---- (c) crew NPROC=3, 3 consumers, storage/retrieval placement
mkc <- function(expr, ret, plc, bigfmt = pq) paste(tm_prelude(NP3, storage = plc, retrieval = ret), sprintf('list(tar_target(big, make_big(%d), %s, deployment = "main", storage = "main"), tar_target_raw("sub1", quote(%s), retrieval = "%s"), tar_target_raw("sub2", quote(%s), retrieval = "%s"), tar_target_raw("sub3", quote(%s), retrieval = "%s"))', MB, bigfmt, expr, ret, expr, ret, expr, ret), sep = "\n")
exn <- sprintf('{ s <- nanoparquet::read_parquet(tar_path_target(big), col_select = %s); colSums(s) }', cols2)
exn_norm <- '{ s <- big[, c("x1", "x2")]; colSums(s) }'
NPL <- sprintf("nproc=%d ", NP3)
cases_c <- list(
  list(paste0(NPL, "normal retrieval=worker"), mkc(exn_norm, "worker", "worker")),
  list(paste0(NPL, "normal retrieval=main (big shipped by main)"), mkc(exn_norm, "main", "worker")),
  list(paste0(NPL, "retrieval=none storage=worker, nanoparquet col_select"), mkc(exn, "none", "worker")),
  list(paste0(NPL, "retrieval=none storage=main, nanoparquet col_select"), mkc(exn, "none", "main")),
  list(paste0(NPL, "qs2 big, retrieval=none, qs_read whole then subset"), mkc('{ s <- qs2::qs_read(tar_path_target(big))[, c("x1", "x2")]; colSums(s) }', "none", "worker", "format = fmt_logged")))
for (cc in cases_c) {
  message("c: ", cc[[1]])
  if (!tm_fits(MB * (2 + 2 * NP3), "c9 c")) next
  r <- tryCatch(tm_run("c9c", cc[[2]], makes = 2, names1 = "big", after = SECS), error = function(e) { message(conditionMessage(e)); NULL })
  if (!is.null(r)) { if (!isTRUE(r$capped)) r$peak_rss_mb <- r$peak_by_make[2]; add(sprintf("c_nproc%d_300MB", NP3), 300, cc[[1]], r, k = 2, notes = sprintf("3 consumers, make 2 only; sub seconds %s; errors=%s", g(r$sub_s), g(r$errors, 0))) }
}

# ---- (d) alternative: big as a format = "file" parquet target
if (tm_fits(MB * 4, "c9 d")) {
src_d <- paste(tm_prelude(1), sprintf('list(tar_target(big_path, { dir.create("data", showWarnings = FALSE); f <- "data/big.parquet"; nanoparquet::write_parquet(make_big(%d), f); f }, format = "file"),
  tar_target(sub, { s <- nanoparquet::read_parquet(big_path, col_select = %s); colSums(s) }))', MB, cols2), sep = "\n")
r <- tm_run("c9d", src_d, makes = 2, names1 = "big_path", after = SECS, between = "")
r$peak_rss_mb <- r$peak_by_make[2]
add("d_file_target_300MB", 300, "format = file parquet target; consumer reads path with col_select", r, k = 2, notes = sprintf("sub seconds %.2f; big_path build seconds %.1f; store bytes %.0f KB (path only; data/ outside store); peak make 2", r$sub_s, r$big_s, r$store_kb))
# 2nd make of d with nothing changed: cost of hashing the 300 MB file
r2 <- tm_run("c9d2", src_d, makes = 3, after = "", between = "")
add("d_file_target_300MB_uptodate", 300, "format = file: up-to-date make (rehashes file)", r2, k = 3, notes = sprintf("3rd make completed=%d skipped=%d", r2$completed[3], r2$skipped[3]))
src_d2 <- paste(tm_prelude(1), sprintf('list(tar_target(big, make_big(%d), %s), tar_target(sub, nrow(big)))', MB, pq), sep = "\n")
r2 <- tm_run("c9d2", src_d2, makes = 3)
add("d_file_target_300MB_uptodate", 300, "format parquet (nanoparquet) store target: up-to-date make", r2, k = 3, notes = sprintf("3rd make completed=%d skipped=%d", r2$completed[3], r2$skipped[3]))
}

# ---- traps: store path with tar_make(store=)
src_t <- paste(tm_prelude(1), 'list(tar_target(big, make_big(5), format = tarchetypes::tar_format_nanoparquet()),
  tar_target(path, c(target_path = tar_path_target(big), exists = file.exists(tar_path_target(big)), store_fn = tryCatch(tar_path_store(), error = function(e) NA)), retrieval = "none"),
  tar_target(path2, c(target_path = tar_path_target(big, store = "alt_store"), exists = file.exists(tar_path_target(big, store = "alt_store"))), retrieval = "none"))', sep = "\n")
r <- tm_run("c9t", src_t, make_args = 'store = "alt_store"', after = 'res$p <- tar_read(path, store = "alt_store"); res$p2 <- tar_read(path2, store = "alt_store")')
add("t_store_arg", 5, "tar_make(store = 'alt_store'): tar_path_target(big) inside command", r, notes = sprintf("default store arg gives: %s ; explicit store='alt_store' gives: %s", fmt1(r$p), fmt1(r$p2)))
cols <- unique(unlist(lapply(rows, names)))
rows <- lapply(rows, function(d) { for (c in setdiff(cols, names(d))) d[[c]] <- NA; d[cols] })
tm_save(do.call(rbind, rows), OUT)
