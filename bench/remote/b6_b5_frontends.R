# Part B5: duckplyr vs dbplyr/duckdb vs arrow for the same filtered remote query (Year=2024).
source("remote/_remote.R")
suppressPackageStartupMessages({library(dplyr); library(dbplyr)})
F <- "b5.csv"
home <- file.path(SCR, "duckhome-b5"); dir.create(home, showWarnings = FALSE)
want <- c("Origin", "Dest", "DepDelay")
norm <- \(x) { x <- as.data.frame(x); x <- x[do.call(order, unname(as.list(x))), , drop = FALSE]; rownames(x) <- NULL; x }
one <- function(method, f, note = "") {
  res <- list()
  for (run in c("run1 cold", "run2 same session")) {
    tm <- system.time(val <- tryCatch(f(), error = \(e) { message("  ", method, " FAILED: ", conditionMessage(e)); NULL }))[["elapsed"]]
    if (is.null(val)) { rec(F, "b5_frontend", paste(method, run), NA, notes = paste("FAILED", note)); return(NULL) }
    rec(F, "b5_frontend", paste(method, run), tm, rows = nrow(val), notes = note)
    message(sprintf("%-28s %-18s %6.2f s rows %d", method, run, tm, nrow(val)))
    res[[run]] <- val
  }
  norm(res[[1]])
}
# duckplyr (default connection; configured through db_exec)
duckplyr::db_exec(sprintf("SET home_directory='%s'", home)); duckplyr::db_exec(sprintf("SET extension_directory='%s'", file.path(home, "ext")))
duckplyr::db_exec("INSTALL httpfs"); duckplyr::db_exec("LOAD httpfs")
r_dp <- one("duckplyr read_parquet_duckdb", \() duckplyr::read_parquet_duckdb(U24, prudence = "stingy") |>
  filter(DepDelay > 300) |> select(all_of(want)) |> collect())
# dbplyr on own duckdb connection
con <- new_con()
r_db <- one("dbplyr tbl(sql read_parquet)", \() tbl(con, sql(sprintf("SELECT * FROM read_parquet('%s')", U24))) |>
  filter(DepDelay > 300) |> select(all_of(want)) |> collect())
r_db2 <- one("dbplyr tbl(I(url))", \() tbl(con, I(sprintf("'%s'", U24))) |> filter(DepDelay > 300) |> select(all_of(want)) |> collect(), "replacement scan on the URL string")
# arrow over https
r_ar <- one("arrow open_dataset(https)", \() arrow::open_dataset(U24, format = "parquet") |> filter(DepDelay > 300) |> select(all_of(want)) |> collect())
r_ar2 <- one("arrow read_parquet(https)", \() arrow::read_parquet(U24, col_select = all_of(want)) |> filter(DepDelay > 300))
for (nm in c("dbplyr", "dbplyr2", "arrow", "arrow2")) {
  o <- list(dbplyr = r_db, dbplyr2 = r_db2, arrow = r_ar, arrow2 = r_ar2)[[nm]]
  message("identical to duckplyr result (sorted, ignoring attrs): ", nm, " = ", if (is.null(o)) NA else isTRUE(all.equal(r_dp, o, check.attributes = FALSE)))
}
