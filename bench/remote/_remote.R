source("_common.R")
SCR <- bench_scratch("b6")
U23 <- "https://blobs.duckdb.org/flight-data-partitioned/Year=2023/data_0.parquet"
U24 <- "https://blobs.duckdb.org/flight-data-partitioned/Year=2024/data_0.parquet"
RES <- "remote/results"
PKGS <- c("duckdb", "duckplyr", "dbplyr", "arrow", "dplyr", "data.table", "curl")

# duckdb connection; shared_home = FALSE keeps ~/.duckdb unchanged; extensions
# installed into a scratch extension dir.
new_con <- function(httpfs = TRUE, home = file.path(SCR, "duckhome"), ...) {
  dir.create(home, showWarnings = FALSE, recursive = TRUE)
  con <- DBI::dbConnect(duckdb::duckdb(config = list(...), shared_home = FALSE), dbdir = ":memory:")
  DBI::dbExecute(con, sprintf("SET home_directory = '%s'", home))
  DBI::dbExecute(con, sprintf("SET extension_directory = '%s'", file.path(home, "ext")))
  if (httpfs) DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
  con
}

# HTTP log accounting: clear logs, enable, run, summarise GET response bytes.
# Bytes = sum of Content-Length of GET responses (HEAD responses carry the file
# size, not a transfer, so are counted as requests only).
http_reset <- function(con) {
  DBI::dbExecute(con, "CALL truncate_duckdb_logs()")
  DBI::dbExecute(con, "CALL enable_logging('HTTP')")
}
http_stats <- function(con) {
  DBI::dbGetQuery(con, "
    SELECT count(*) AS n_req,
      count(*) FILTER (WHERE message LIKE '%''type'': GET%') AS n_get,
      count(*) FILTER (WHERE message LIKE '%''type'': HEAD%') AS n_head,
      coalesce(sum(try_cast(regexp_extract(message, '''type'': GET.*?Content-Length=([0-9]+)', 1) AS BIGINT)), 0) / 1048576.0 AS mb
    FROM duckdb_logs WHERE type = 'HTTP'")
}
# Run f() once; return wall seconds + HTTP stats since reset.
timed <- function(con, f, reset = TRUE) {
  if (reset) http_reset(con)
  t <- system.time(val <- f())[["elapsed"]]
  list(sec = t, http = http_stats(con), val = val)
}
rec <- function(file, task, method, sec, n_get = NA, n_head = NA, mb = NA, rows = NA, notes = "") {
  out <- data.frame(topic = "remote", task = task, n = NA_real_, method = method, seconds = sec,
                    n_get = n_get, n_head = n_head, mb_fetched = mb, rows = rows, notes = notes,
                    packages = pkg_versions(PKGS))
  out <- cbind(out, bench_env())
  write_result(out, file.path(RES, file))
  invisible(out)
}
rec_t <- function(file, task, method, tm, rows = NA, notes = "")
  rec(file, task, method, tm$sec, tm$http$n_get, tm$http$n_head, tm$http$mb, rows, notes)

# Per-URL request counts from the HTTP log (which files were touched)
http_by_url <- function(con) {
  DBI::dbGetQuery(con, "
    SELECT regexp_extract(message, '''url'': ''([^'']+)''', 1) AS url, count(*) AS n,
      coalesce(sum(try_cast(regexp_extract(message, '''type'': GET.*?Content-Length=([0-9]+)', 1) AS BIGINT)), 0) / 1048576.0 AS mb
    FROM duckdb_logs WHERE type = 'HTTP' GROUP BY 1 ORDER BY 1")
}
# Fresh connection with no caching of any kind (cold by construction)
cold_con <- function(...) {
  con <- new_con(...)
  DBI::dbExecute(con, "SET enable_external_file_cache = false")
  con
}
q_cols <- function(cols) paste(sprintf('"%s"', cols), collapse = ", ")
