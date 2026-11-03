# Part A: query ordering, local. Synthetic 2e6-row table; frameworks: dplyr, data.table, duckplyr, dbplyr/duckdb.
source("remote/_remote.R")
suppressPackageStartupMessages({library(dplyr); library(data.table); library(dbplyr)})
set.seed(1)
n <- 2e6
check_fits(250, 6, "ordering")
fact <- data.frame(id = 1:n, g = sample.int(1000, n, TRUE), code = sprintf("C%05d", sample.int(20000, n, TRUE)),
                   x = runif(n), y = rnorm(n))
fact$txt <- paste0("Item-", sample.int(1e5, n, TRUE), "-", sample(letters, n, TRUE), "_", fact$g)
dim <- data.frame(g = 1:1000, cat = rep(c("A", "B"), c(50, 950)), w = runif(1000))
message("fact: ", format(object.size(fact), units = "MB"))
dir.create(SCR, showWarnings = FALSE, recursive = TRUE)
pq <- file.path(SCR, "fact_syn.parquet")
nanoparquet::write_parquet(fact, pq)
dt <- as.data.table(fact); dtd <- as.data.table(dim)

dh <- file.path(SCR, "duckhome-a"); dir.create(dh, showWarnings = FALSE)
con <- DBI::dbConnect(duckdb::duckdb(config = list(memory_limit = "3GB"), shared_home = FALSE), ":memory:")
DBI::dbExecute(con, sprintf("SET home_directory='%s'", dh))
duckdb::duckdb_register(con, "dim", dim)
dbf <- tbl(con, sql(sprintf("SELECT * FROM read_parquet('%s')", pq)))
dbd <- tbl(con, "dim")
duckplyr::db_exec(sprintf("SET home_directory='%s'", dh)); duckplyr::db_exec("SET memory_limit='3GB'")
dpf <- duckplyr::read_parquet_duckdb(pq, prudence = "stingy")
dpd <- duckplyr::as_duckdb_tibble(dim, prudence = "stingy")

norm <- function(x, keys) {
  x <- as.data.frame(x); x <- x[do.call(order, unname(as.list(x[keys]))), , drop = FALSE]
  rownames(x) <- NULL; x[sort(names(x))]
}
ex <- function(s) gsub("[0-9]+", "#", s)   # the "expensive" per-row op (regex)
exq <- function(v) rlang::expr(stringr::str_replace_all(!!rlang::sym(v), "[0-9]+", "#"))  # same, inlined for dbplyr SQL translation
exd <- function(v) rlang::expr(gsub("[0-9]+", "#", !!rlang::sym(v)))  # duckplyr translates gsub, not str_replace_all

# ---- pipelines: each returns a collected data frame ----
P <- list()
P$a1_mutate_filter <- list(keys = "id",
  dplyr_bad  = \() fact |> mutate(out = ex(txt)) |> filter(x > 0.95) |> select(id, out),
  dplyr_good = \() fact |> filter(x > 0.95) |> mutate(out = ex(txt)) |> select(id, out),
  dt_bad  = \() { d <- copy(dt); d[, out := ex(txt)][x > 0.95, .(id, out)] },
  dt_good = \() dt[x > 0.95, .(id, out = ex(txt))],
  duckplyr_bad  = \() dpf |> mutate(out = !!exd("txt")) |> filter(x > 0.95) |> select(id, out) |> collect(),
  duckplyr_good = \() dpf |> filter(x > 0.95) |> mutate(out = !!exd("txt")) |> select(id, out) |> collect(),
  dbplyr_bad  = \() dbf |> mutate(out = !!exq("txt")) |> filter(x > 0.95) |> select(id, out) |> collect(),
  dbplyr_good = \() dbf |> filter(x > 0.95) |> mutate(out = !!exq("txt")) |> select(id, out) |> collect())
P$a2a_join_filter_fact <- list(keys = "id",
  dplyr_bad  = \() fact |> inner_join(dim, "g") |> filter(x > 0.99) |> select(id, g, x, cat),
  dplyr_good = \() fact |> filter(x > 0.99) |> inner_join(dim, "g") |> select(id, g, x, cat),
  dt_bad  = \() dt[dtd, on = "g", nomatch = 0][x > 0.99, .(id, g, x, cat)],
  dt_good = \() dt[x > 0.99][dtd, on = "g", nomatch = 0][, .(id, g, x, cat)],
  duckplyr_bad  = \() dpf |> inner_join(dpd, "g") |> filter(x > 0.99) |> select(id, g, x, cat) |> collect(),
  duckplyr_good = \() dpf |> filter(x > 0.99) |> inner_join(dpd, "g") |> select(id, g, x, cat) |> collect(),
  dbplyr_bad  = \() dbf |> inner_join(dbd, "g") |> filter(x > 0.99) |> select(id, g, x, cat) |> collect(),
  dbplyr_good = \() dbf |> filter(x > 0.99) |> inner_join(dbd, "g") |> select(id, g, x, cat) |> collect())
P$a2b_join_filter_dim <- list(keys = "id",
  dplyr_bad  = \() fact |> inner_join(dim, "g") |> filter(cat == "A") |> select(id, g, x, cat),
  dplyr_good = \() fact |> inner_join(filter(dim, cat == "A"), "g") |> select(id, g, x, cat),
  dplyr_semi = \() fact |> semi_join(filter(dim, cat == "A"), "g") |> inner_join(dim, "g") |> select(id, g, x, cat),
  dt_bad  = \() dt[dtd, on = "g", nomatch = 0][cat == "A", .(id, g, x, cat)],
  dt_good = \() dt[dtd[cat == "A"], on = "g", nomatch = 0][, .(id, g, x, cat)],
  duckplyr_bad  = \() dpf |> inner_join(dpd, "g") |> filter(cat == "A") |> select(id, g, x, cat) |> collect(),
  duckplyr_good = \() dpf |> inner_join(filter(dpd, cat == "A"), "g") |> select(id, g, x, cat) |> collect(),
  dbplyr_bad  = \() dbf |> inner_join(dbd, "g") |> filter(cat == "A") |> select(id, g, x, cat) |> collect(),
  dbplyr_good = \() dbf |> inner_join(filter(dbd, cat == "A"), "g") |> select(id, g, x, cat) |> collect())
P$a2c_join_agg <- list(keys = "g",
  dplyr_bad  = \() fact |> inner_join(dim, "g") |> summarise(m = mean(x), n = n(), .by = c(g, cat)),
  dplyr_good = \() fact |> summarise(m = mean(x), n = n(), .by = g) |> inner_join(dim, "g") |> select(g, cat, m, n),
  dt_bad  = \() dt[dtd, on = "g", nomatch = 0][, .(m = mean(x), n = .N), by = .(g, cat)],
  dt_good = \() merge(dt[, .(m = mean(x), n = .N), by = g], dtd[, .(g, cat)], by = "g"),
  duckplyr_bad  = \() dpf |> inner_join(dpd, "g") |> summarise(m = mean(x), n = n(), .by = c(g, cat)) |> collect(),
  duckplyr_good = \() dpf |> summarise(m = mean(x), n = n(), .by = g) |> inner_join(dpd, "g") |> select(g, cat, m, n) |> collect(),
  dbplyr_bad  = \() dbf |> inner_join(dbd, "g") |> summarise(m = mean(x), n = n(), .by = c(g, cat)) |> collect(),
  dbplyr_good = \() dbf |> summarise(m = mean(x), n = n(), .by = g) |> inner_join(dbd, "g") |> select(g, cat, m, n) |> collect())
P$a3a_arrange_early <- list(keys = "id",
  dplyr_bad  = \() fact |> arrange(x) |> filter(x > 0.95) |> mutate(out = ex(txt)) |> select(id, x, out),
  dplyr_good = \() fact |> filter(x > 0.95) |> mutate(out = ex(txt)) |> arrange(x) |> select(id, x, out),
  dt_bad  = \() { d <- copy(dt); setorder(d, x); d[x > 0.95, .(id, x, out = ex(txt))] },
  dt_good = \() { r <- dt[x > 0.95, .(id, x, out = ex(txt))]; setorder(r, x); r },
  duckplyr_bad  = \() dpf |> arrange(x) |> filter(x > 0.95) |> mutate(out = !!exd("txt")) |> select(id, x, out) |> collect(),
  duckplyr_good = \() dpf |> filter(x > 0.95) |> mutate(out = !!exd("txt")) |> arrange(x) |> select(id, x, out) |> collect(),
  dbplyr_bad  = \() dbf |> arrange(x) |> filter(x > 0.95) |> mutate(out = !!exq("txt")) |> select(id, x, out) |> collect(),
  dbplyr_good = \() dbf |> filter(x > 0.95) |> mutate(out = !!exq("txt")) |> arrange(x) |> select(id, x, out) |> collect())
P$a3b_distinct_first <- list(keys = "code",
  dplyr_bad  = \() fact |> mutate(out = ex(code)) |> distinct(code, out),
  dplyr_good = \() fact |> distinct(code) |> mutate(out = ex(code)),
  dt_bad  = \() unique(dt[, .(code, out = ex(code))]),
  dt_good = \() unique(dt[, .(code)])[, out := ex(code)][],
  duckplyr_bad  = \() dpf |> mutate(out = !!exd("code")) |> distinct(code, out) |> collect(),
  duckplyr_good = \() dpf |> distinct(code) |> mutate(out = !!exd("code")) |> collect(),
  dbplyr_bad  = \() dbf |> mutate(out = !!exq("code")) |> distinct(code, out) |> collect(),
  dbplyr_good = \() dbf |> distinct(code) |> mutate(out = !!exq("code")) |> collect())

# ---- run ----
out_file <- file.path(RES, "ordering.csv")
for (task in names(P)) {
  keys <- P[[task]]$keys; fns <- P[[task]][names(P[[task]]) != "keys"]
  # first, one run each to validate (and catch fallbacks / errors)
  vals <- lapply(fns, \(f) tryCatch(norm(f(), keys), error = \(e) { message("  FAIL ", conditionMessage(e)); NULL }))
  ref <- vals$dplyr_good
  same <- vapply(names(fns), \(m) !is.null(vals[[m]]) && isTRUE(all.equal(ref, vals[[m]], tolerance = 1e-9, check.attributes = FALSE)), logical(1))
  message(task, " rows=", nrow(ref), " same: ", paste(names(same)[same], collapse = ","), " | DIFF/FAIL: ", paste(names(same)[!same], collapse = ","))
  ok <- names(fns)[!vapply(vals, is.null, TRUE)]
  rm(vals); invisible(gc())
  tm <- vapply(ok, \(m) { f <- fns[[m]]; ts <- vapply(1:3, \(i) system.time(f())[["elapsed"]], 0); median(ts) }, 0)
  for (m in names(fns)) {
    r <- data.frame(topic = "ordering", task = task, n = n, method = m, median_s = unname(tm[m]),
                    ratio_to_fastest = NA_real_, mem_alloc_mb = NA_real_, n_itr = 3L, identical_to_ref = unname(same[m]),
                    notes = if (m %in% ok) "" else "FAILED (error/unsupported)", packages = pkg_versions(PKGS))
    r$ratio_to_fastest <- r$median_s / min(tm, na.rm = TRUE)
    r <- cbind(r, bench_env()); write_result(r, out_file)
  }
  print(round(tm, 3))
}

# ---- EXPLAIN: bad-order pipelines on parquet ----
exf <- file.path(RES, "ordering_explain.txt"); sink(exf)
cat("EXPLAIN of bad-order pipelines, duckdb 2.0.0, synthetic 2e6-row parquet. dbplyr: DBI EXPLAIN of sql_render; duckplyr: dplyr::explain().\n\n")
q1 <- dbf |> mutate(out = !!exq("txt")) |> filter(x > 0.95) |> select(id, out)
cat("=== a1 dbplyr SQL ===\n"); print(dbplyr::sql_render(q1))
cat("\n=== a1 dbplyr EXPLAIN ===\n"); cat(DBI::dbGetQuery(con, paste("EXPLAIN", dbplyr::sql_render(q1)))[[2]], "\n")
q2 <- dbf |> inner_join(dbd, "g") |> filter(x > 0.99) |> select(id, g, x, cat)
cat("\n=== a2a dbplyr EXPLAIN ===\n"); cat(DBI::dbGetQuery(con, paste("EXPLAIN", dbplyr::sql_render(q2)))[[2]], "\n")
cat("\n=== a1 duckplyr explain ===\n")
try(dpf |> mutate(out = !!exd("txt")) |> filter(x > 0.95) |> select(id, out) |> dplyr::explain())
cat("\n=== a2a duckplyr explain ===\n")
try(dpf |> inner_join(dpd, "g") |> filter(x > 0.99) |> select(id, g, x, cat) |> dplyr::explain())
sink()

# ---- A5: store size of filtering/selecting early ----
sz <- function(obj, nm) {
  f1 <- tempfile(tmpdir = SCR, fileext = ".qs2"); qs2::qs_save(obj, f1, nthreads = 1)
  f2 <- tempfile(tmpdir = SCR, fileext = ".parquet"); nanoparquet::write_parquet(obj, f2)
  r <- data.frame(object = nm, rows = nrow(obj), cols = ncol(obj), ram_mb = as.numeric(object.size(obj)) / 2^20,
                  qs2_mb = file.size(f1) / 2^20, parquet_mb = file.size(f2) / 2^20)
  unlink(c(f1, f2)); r
}
ss <- rbind(sz(fact, "full"), sz(fact[c("id", "g", "x")], "3 cols"), sz(fact[fact$x > 0.95, ], "filtered 5% rows, all cols"),
            sz(fact[fact$x > 0.95, c("id", "g", "x")], "filtered 5% + 3 cols"), sz(fact[fact$x > 0.99, c("id", "g", "x")], "filtered 1% + 3 cols"))
ss$as_of <- format(Sys.Date()); ss$notes <- "synthetic 2e6-row table; qs2 nthreads=1 default level; nanoparquet default"
utils::write.csv(ss, file.path(RES, "ordering_store_size.csv"), row.names = FALSE)
print(ss)
unlink(pq)
