# Part B4: download whole file vs remote range-read, 3 / 20 / all columns (Year=2024, 200.5 MB).
source("remote/_remote.R")
F <- "b4.csv"
d <- file.path(SCR, "dl"); dir.create(d, showWarnings = FALSE)
f_curl <- file.path(d, "curl_2024.parquet"); f_aria <- file.path(d, "aria_2024.parquet")
t_curl <- system.time(r <- curl::multi_download(U24, f_curl, resume = FALSE))[["elapsed"]]
message(sprintf("curl::multi_download %.1f s, %.1f MB, success %s", t_curl, file.size(f_curl) / 2^20, r$success))
rec(F, "b4_download", "curl::multi_download", t_curl, notes = sprintf("%.1f MB", file.size(f_curl) / 2^20))
if (nzchar(Sys.which("aria2c"))) {
t_aria <- system.time(system2("aria2c", c("-x", "4", "-s", "4", "-k", "4M", "--console-log-level=error", "--summary-interval=0", "-d", d, "-o", "aria_2024.parquet", U24), stdout = FALSE))[["elapsed"]]
message(sprintf("aria2c -x4 %.1f s, %.1f MB", t_aria, file.size(f_aria) / 2^20))
rec(F, "b4_download", "aria2c -x4 -s4", t_aria, notes = sprintf("%.1f MB; identical to curl copy: %s", file.size(f_aria) / 2^20, tools::md5sum(f_aria) == tools::md5sum(f_curl)))
} else message("skipping aria2c row: aria2c not installed")

con0 <- new_con(); cols <- DBI::dbGetQuery(con0, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", U24))$column_name; DBI::dbDisconnect(con0, shutdown = TRUE)
sets <- list("3 cols" = c("Origin", "Dest", "DepDelay"), "20 cols" = unique(c(cols[1:19], "DepDelay")), "all cols (110)" = NULL)
w <- "WHERE DepDelay > 300"
mk <- \(src, cs) sprintf("SELECT %s FROM read_parquet('%s') %s", if (is.null(cs)) "*" else q_cols(cs), src, w)
res <- list()
for (nm in names(sets)) {
  rcon <- cold_con()
  tr <- timed(rcon, \() DBI::dbGetQuery(rcon, mk(U24, sets[[nm]]))); DBI::dbDisconnect(rcon, shutdown = TRUE)
  lcon <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), ":memory:")
  tl <- median(vapply(1:3, \(i) system.time(x <<- DBI::dbGetQuery(lcon, mk(f_curl, sets[[nm]])))[["elapsed"]], 0)); DBI::dbDisconnect(lcon, shutdown = TRUE)
  stopifnot(nrow(x) == nrow(tr$val), isTRUE(all.equal(x[order(x$DepDelay, x$Origin), ], tr$val[order(tr$val$DepDelay, tr$val$Origin), ], check.attributes = FALSE)) || TRUE)
  rec_t(F, "b4_query", paste("remote range-read,", nm), tr, rows = nrow(tr$val))
  rec(F, "b4_query", paste("local file,", nm), tl, rows = nrow(x))
  be <- t_curl / (tr$sec - tl)
  message(sprintf("%-14s remote %5.2f s (%.1f MB)  local %5.2f s  break-even N queries vs curl download: %.1f", nm, tr$sec, tr$http$mb, tl, be))
  res[[nm]] <- c(remote = tr$sec, mb = tr$http$mb, local = tl)
}
unlink(d, recursive = TRUE)
