# Part B1 projection, B2 partition pruning / row-group stats (remote Year=2024 / 2023).
source("remote/_remote.R")
F <- "b12.csv"
con0 <- new_con()
cols <- DBI::dbGetQuery(con0, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", U24))
message("ncols ", nrow(cols)); message(paste(cols$column_name[1:30], collapse = " "))
DBI::dbDisconnect(con0, shutdown = TRUE)
C3 <- c("Origin", "Dest", "DepDelay"); stopifnot(all(C3 %in% cols$column_name))
C20 <- unique(c(cols$column_name[1:19], "DepDelay"))
stopifnot("FlightDate" %in% cols$column_name)

run <- function(label, sql, task, url_check = FALSE) {
  con <- cold_con()   # fresh connection, external file cache off
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  tm <- timed(con, \() DBI::dbGetQuery(con, sql))
  rec_t(F, task, label, tm, rows = nrow(tm$val))
  message(sprintf("%-14s %-34s %6.2f s  GET %3d  HEAD %d  %7.1f MB  rows %s", task, label, tm$sec,
                  tm$http$n_get, tm$http$n_head, tm$http$mb, nrow(tm$val)))
  if (url_check) print(http_by_url(con))
  invisible(tm)
}
rd <- \(u) sprintf("read_parquet('%s')", u)
w <- "WHERE DepDelay > 300"
# B1 projection
run("3 cols, filter DepDelay>300", sprintf("SELECT %s FROM %s %s", q_cols(C3), rd(U24), w), "b1_projection")
run("20 cols, filter DepDelay>300", sprintf("SELECT %s FROM %s %s", q_cols(C20), rd(U24), w), "b1_projection")
run("all cols, filter DepDelay>300", sprintf("SELECT * FROM %s %s", rd(U24), w), "b1_projection")
run("count(*) only (footer)", sprintf("SELECT count(*) FROM %s", rd(U24)), "b1_projection")
# B2 partition pruning
two <- sprintf("read_parquet(['%s', '%s'], hive_partitioning = true)", U23, U24)
run("2 urls, Year = 2024 (hive)", sprintf("SELECT %s FROM %s WHERE Year = 2024 AND DepDelay > 300", q_cols(C3), two), "b2_pruning", TRUE)
run("2 urls, no Year filter", sprintf("SELECT %s FROM %s WHERE DepDelay > 300", q_cols(C3), two), "b2_pruning", TRUE)
# row-group stats on a non-partition column (single 2024 file, 3 cols)
run("filter FlightDate = one day", sprintf("SELECT %s FROM %s WHERE FlightDate = DATE '2024-03-01'", q_cols(C3), rd(U24)), "b2_rowgroup")
run("filter Origin = 'JFK'", sprintf("SELECT %s FROM %s WHERE Origin = 'JFK'", q_cols(C3), rd(U24)), "b2_rowgroup")
run("no filter, 3 cols (count)", sprintf("SELECT count(Origin), count(Dest), count(DepDelay) FROM %s", rd(U24)), "b2_rowgroup")
con <- new_con(); print(DBI::dbGetQuery(con, sprintf("SELECT count(DISTINCT row_group_id) rgs, min(row_group_num_rows) mn, max(row_group_num_rows) mx FROM parquet_metadata('%s')", U24)))
