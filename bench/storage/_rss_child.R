# usage: Rscript _rss_child.R <method> <path> <filter_col> <colsCSV>  ; env THREADS (optional)
a <- commandArgs(TRUE); m <- a[1]; p <- a[2]; fcol <- a[3]; cols <- strsplit(a[4], ",")[[1]]
nt <- as.integer(Sys.getenv("QS_NT", "4"))
th <- Sys.getenv("THREADS", ""); th <- if (nzchar(th)) as.integer(th) else NULL
suppressPackageStartupMessages({library(qs2); library(nanoparquet); library(arrow); library(DBI); library(duckdb); library(dplyr)})
if (!is.null(th)) { arrow::set_cpu_count(th) }
dq <- function(sql) { con <- dbConnect(duckdb()); on.exit(dbDisconnect(con, shutdown = TRUE)); if (!is.null(th)) dbExecute(con, paste0("SET threads=", th)); dbGetQuery(con, sql) }
cutoff <- as.integer(Sys.getenv("CUT", "10000"))
res <- switch(m,
  baseline = NULL,
  qs2_full = qs2::qs_read(p, nthreads = if (is.null(th)) nt else th),
  qs2_full_cols = qs2::qs_read(p, nthreads = if (is.null(th)) nt else th)[, cols],
  np_full = nanoparquet::read_parquet(p),
  np_cols = nanoparquet::read_parquet(p, col_select = cols),
  arrow_full = arrow::read_parquet(p),
  arrow_cols = arrow::read_parquet(p, col_select = cols),
  duck_cols = dq(sprintf("SELECT %s FROM read_parquet('%s')", paste(cols, collapse = ","), p)),
  arrow_filter = arrow::open_dataset(p) |> filter(.data[[fcol]] <= cutoff) |> collect(),
  duck_filter = dq(sprintf("SELECT * FROM read_parquet('%s') WHERE %s <= %d", p, fcol, cutoff)),
  np_full_filter = { d <- nanoparquet::read_parquet(p); d[d[[fcol]] <= cutoff, ] },
  qs2_full_filter = { d <- qs2::qs_read(p, nthreads = if (is.null(th)) nt else th); d[d[[fcol]] <= cutoff, ] })
invisible(NROW(res))
