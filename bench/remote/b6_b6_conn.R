# Part B6 connection reuse (x20 calls) and B7 threads / memory_limit.
source("remote/_remote.R")
F <- "b67.csv"
home <- file.path(SCR, "duckhome"); dir.create(home, showWarnings = FALSE, recursive = TRUE)
# pre-install httpfs once so per-call INSTALL is the "already installed" path
invisible(new_con())
mk_con <- function(with_secret = TRUE) {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), ":memory:")
  DBI::dbExecute(con, sprintf("SET home_directory = '%s'", home)); DBI::dbExecute(con, sprintf("SET extension_directory = '%s'", file.path(home, "ext")))
  DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
  # dummy scoped secret: no credentials, scope never matches https URLs
  if (with_secret) DBI::dbExecute(con, "CREATE OR REPLACE SECRET s (TYPE s3, KEY_ID 'dummy', SECRET 'dummy', SCOPE 's3://no-such-bucket/')")
  con
}
.memo <- new.env()
get_con <- function() {
  if (is.null(.memo$con) || !DBI::dbIsValid(.memo$con)) .memo$con <- mk_con()
  .memo$con
}
Qn <- sprintf("SELECT count(*) AS n FROM read_parquet('%s')", U24)   # footer only: 4 GETs
N <- 20
tm_loop <- function(f) system.time(for (i in seq_len(N)) f())[["elapsed"]]
# overhead only
t_new0 <- tm_loop(\() { con <- mk_con(); DBI::dbGetQuery(con, "SELECT 1"); DBI::dbDisconnect(con, shutdown = TRUE) })
t_memo0 <- tm_loop(\() DBI::dbGetQuery(get_con(), "SELECT 1")); DBI::dbDisconnect(.memo$con, shutdown = TRUE); rm(list = "con", envir = .memo)
# with a remote footer query each call
t_new1 <- tm_loop(\() { con <- mk_con(); DBI::dbGetQuery(con, Qn); DBI::dbDisconnect(con, shutdown = TRUE) })
t_memo1 <- tm_loop(\() DBI::dbGetQuery(get_con(), Qn)); DBI::dbDisconnect(.memo$con, shutdown = TRUE)
for (r in list(c("new connection + INSTALL/LOAD httpfs + secret, SELECT 1", t_new0), c("memoized connection, SELECT 1", t_memo0),
               c("new connection each call, remote count(*)", t_new1), c("memoized connection, remote count(*)", t_memo1)))
  { rec(F, "b6_conn_reuse", r[1], as.numeric(r[2]), notes = sprintf("x%d calls total; %.0f ms/call", N, 1000 * as.numeric(r[2]) / N)); message(sprintf("%-60s %6.2f s total, %5.0f ms/call", r[1], as.numeric(r[2]), 1000 * as.numeric(r[2]) / N)) }

# B7 defaults + settings
con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), ":memory:")
d <- DBI::dbGetQuery(con, "SELECT current_setting('threads') threads, current_setting('memory_limit') memory_limit, current_setting('max_memory') max_memory")
print(d)
ram_gb <- ps::ps_system_memory()$total / 2^30
message(sprintf("RAM %.1f GiB; default memory_limit per process = 80%%; N workers can claim N x %s", ram_gb, d$memory_limit))
rec(F, "b7_defaults", "default threads/memory_limit", NA, notes = sprintf("threads=%s memory_limit=%s RAM=%.1f GiB cores=%d", d$threads, d$memory_limit, ram_gb, bench_cores()))
DBI::dbDisconnect(con, shutdown = TRUE)
# set via config at connect, and via SET
con <- DBI::dbConnect(duckdb::duckdb(config = list(threads = "2", memory_limit = "2GB"), shared_home = FALSE), ":memory:")
print(DBI::dbGetQuery(con, "SELECT current_setting('threads') threads, current_setting('memory_limit') memory_limit"))
DBI::dbExecute(con, "SET threads = 1"); print(DBI::dbGetQuery(con, "SELECT current_setting('threads') threads"))
DBI::dbDisconnect(con, shutdown = TRUE)
# threads sweep, remote 3-col query, cold each
Q3 <- sprintf("SELECT %s FROM read_parquet('%s') WHERE DepDelay > 300", q_cols(c("Origin", "Dest", "DepDelay")), U24)
for (th in thread_set(c(1, 2, 4, 12))) {
  con <- cold_con(); DBI::dbExecute(con, sprintf("SET threads = %d", th))
  tm <- timed(con, \() DBI::dbGetQuery(con, Q3)); DBI::dbDisconnect(con, shutdown = TRUE)
  rec_t(F, "b7_threads_remote", paste("threads", th), tm, rows = nrow(tm$val))
  message(sprintf("threads %2d  remote 3-col cold %5.2f s  GET %d  %.1f MB", th, tm$sec, tm$http$n_get, tm$http$mb))
}
