# Part B3 caches: external file cache, http metadata cache, parquet metadata cache, cache_httpfs (disk, across 2 fresh R sessions).
source("remote/_remote.R")
F <- "b3.csv"
Q3 <- sprintf("SELECT %s FROM read_parquet('%s') WHERE DepDelay > 300", q_cols(c("Origin", "Dest", "DepDelay")), U24)
Q3b <- sprintf("SELECT %s FROM read_parquet('%s') WHERE DepDelay > 300", q_cols(c("Origin", "Dest", "ArrDelay")), U24)  # other cols, same file
show <- function(task, method, tm, notes = "") {
  rec_t(F, task, method, tm, rows = nrow(tm$val), notes = notes)
  message(sprintf("%-22s %-40s %6.2f s  GET %3d  HEAD %d  %6.1f MB %s", task, method, tm$sec, tm$http$n_get, tm$http$n_head, tm$http$mb, notes))
}
q <- \(con, sql) timed(con, \() DBI::dbGetQuery(con, sql))

# (a) core external file cache, same session
for (on in c(TRUE, FALSE)) {
  con <- new_con(); DBI::dbExecute(con, sprintf("SET enable_external_file_cache = %s", on))
  show("b3a_ext_cache", sprintf("cache=%s run1 (cold)", on), q(con, Q3))
  show("b3a_ext_cache", sprintf("cache=%s run2 same query", on), q(con, Q3))
  show("b3a_ext_cache", sprintf("cache=%s run3 other cols", on), q(con, Q3b))
  DBI::dbDisconnect(con, shutdown = TRUE)
}
# (b) http metadata cache / parquet metadata cache settings (external cache off to isolate)
con <- new_con()
print(DBI::dbGetQuery(con, "SELECT name, value, description FROM duckdb_settings() WHERE name ILIKE '%cache%' OR name ILIKE '%metadata%'")[, 1:2])
for (cfg in list(c("off", "SET enable_external_file_cache=false; SET enable_http_metadata_cache=false"),
                 c("http_meta on", "SET enable_external_file_cache=false; SET enable_http_metadata_cache=true"),
                 c("http_meta + parquet_meta on", "SET enable_external_file_cache=false; SET enable_http_metadata_cache=true; SET parquet_metadata_cache=true"))) {
  con <- new_con()
  ok <- tryCatch({ for (s in strsplit(cfg[2], "; ")[[1]]) DBI::dbExecute(con, s); TRUE }, error = \(e) { message("  setting failed: ", conditionMessage(e)); FALSE })
  if (!ok) next
  show("b3b_meta_cache", paste0(cfg[1], " run1"), q(con, Q3))
  show("b3b_meta_cache", paste0(cfg[1], " run2 other cols"), q(con, Q3b))
  DBI::dbDisconnect(con, shutdown = TRUE)
}
# (c) cache_httpfs: two fresh R sessions (callr), on-disk cache in scratch
cdir <- file.path(SCR, "cache_httpfs"); unlink(cdir, recursive = TRUE); dir.create(cdir)
sess <- function(tag) callr::r(function(tag, cdir, scr_src, Q3) {
  source("remote/_remote.R")
  con <- new_con()
  r <- tryCatch({
    DBI::dbExecute(con, "INSTALL cache_httpfs FROM community")
    DBI::dbExecute(con, "LOAD cache_httpfs")
    DBI::dbExecute(con, sprintf("SET cache_httpfs_cache_directory = '%s'", cdir))
    DBI::dbExecute(con, "SET cache_httpfs_type = 'on_disk'")
    "ok" }, error = \(e) conditionMessage(e))
  if (r != "ok") return(list(status = r))
  tm <- timed(con, \() DBI::dbGetQuery(con, Q3))
  info <- tryCatch(DBI::dbGetQuery(con, "SELECT * FROM cache_httpfs_cache_access_info_query()"), error = \(e) conditionMessage(e))
  list(status = r, sec = tm$sec, http = tm$http, rows = nrow(tm$val), info = info,
       ver = DBI::dbGetQuery(con, "SELECT extension_version FROM duckdb_extensions() WHERE extension_name='cache_httpfs'")[[1]])
}, list(tag = tag, cdir = cdir, scr_src = normalizePath("remote/b6_b3_cache.R"), Q3 = Q3), wd = getwd(), show = FALSE)
for (tag in c("session 1 (cold)", "session 2 (warm, fresh R)", "session 3 (warm, fresh R)")) {
  r <- sess(tag)
  if (r$status != "ok") { message("cache_httpfs FAILED: ", r$status); rec(F, "b3c_cache_httpfs", tag, NA, notes = paste("FAILED:", r$status)); break }
  tm <- list(sec = r$sec, http = r$http, val = data.frame(x = seq_len(r$rows))); show("b3c_cache_httpfs", tag, tm, paste("ext", r$ver))
  print(r$info)
}
message("cache dir size MB: ", round(sum(file.size(list.files(cdir, recursive = TRUE, full.names = TRUE))) / 2^20, 1))
unlink(cdir, recursive = TRUE)
