# Operation order: do less work, earlier


**When this matters.** A target filters, joins, aggregates or sorts a large table and spends its time on rows or columns it later drops; or big intermediate targets are cached only to be filtered downstream. Database optimizers reorder such work automatically. dplyr, data.table and base R run your steps in the order written.

## The rules

1.  **Filter early** (predicate pushdown): filter before an expensive `mutate()`, before joins, before per-row functions.
2.  **Select early** (projection pushdown): keep only needed columns, especially before joins and before saving.
3.  **Aggregate before joining** when the join only adds labels to a summary.
4.  **Filter with a semi-join** (or filter the small table) before an expensive join.
5.  **Deduplicate before costly per-row work**: run `distinct()` / `unique()` on the inputs of an expensive function, compute, then join or `match()` back (`vectorization.md`).
6.  **Sort last**, or not at all.
7.  **Avoid wide intermediates**: do not join everything into one wide table "just in case".

## Measured: wrong order vs right order

Ratio = time with the expensive step first / time with the cheap reduction first. 2e6 rows; every variant returned the same result.

| pipeline | dplyr | data.table | duckplyr | dbplyr + duckdb |
|:---|:---|:---|:---|:---|
| regex `mutate()` then `filter()` (5% kept) | 15x | 16x | 1.2x | 1.0x |
| join then filter on a fact column (1% kept) | 8.3x | 19x | 1.0x | 0.93x |
| join then filter on a dimension column | 3.3x | 7.8x | 1.1x | 0.93x |
| join then aggregate (vs aggregate then join) | 4.0x | 11x | 1.3x | 1.0x |
| `arrange()` first (vs last) | 3.3x | 2.8x | 2.0x | 1.0x |
| regex on all rows then `distinct()` (vs distinct first) | 30x | 15x | 3.5x | 2.2x |

Source: benchmark results `remote/ordering.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). dplyr and data.table ran in memory; duckplyr and dbplyr read the same table from a local parquet file. All 49 of 49 variants matched the reference result.

What the optimizer does and does not do:

- DuckDB (via duckplyr or dbplyr) **pushed filters and column selection into the parquet scan** and below joins, so the bad order cost almost nothing. `EXPLAIN` shows it: `Read Parquet ... Projections: id, txt; Filters: x > 0.95` under the projection, and the filter below the hash join.
- It did **not** fix `arrange()` placed early (duckplyr), and it did **not** move `distinct()` ahead of an expensive expression. Write sort-last and distinct-first by hand, even for duckdb.
- dplyr and data.table never reorder. Their bad orders were the slowest of all.

## In a pipeline: filter in the upstream target

The cache is part of the cost. A target that stores the full table makes every downstream target load the full table. Putting the filter and the column selection in the upstream target shrank this table's store size:

| stored                     | in memory | qs2    | parquet |
|:---------------------------|:----------|:-------|:--------|
| full                       | 224 MB    | 46 MB  | 69 MB   |
| 3 cols                     | 31 MB     | 13 MB  | 23 MB   |
| filtered 5% rows, all cols | 13 MB     | 2.5 MB | 3.4 MB  |
| filtered 5% + 3 cols       | 1.9 MB    | 0.9 MB | 1.1 MB  |
| filtered 1% + 3 cols       | 0.4 MB    | 0.2 MB | 0.2 MB  |

Source: benchmark results `remote/ordering_store_size.csv` (run 2026-11-03).

Smaller stored targets save write time, every downstream load, memory per worker, and the hidden I/O `tar_profile.R` reports. Split a "clean everything" target into a filtered, selected core plus separate targets for the rarely used columns.

## Hand-ordering vs letting duckdb order

- Rewriting a dplyr pipeline in the right order keeps the output identical and needs no new dependency. Do this first.
- Running it through duckdb (`duckplyr::as_duckdb_tibble()`, or dbplyr on a duckdb connection) also gets pushdown for free, and pays most for data that already live in parquet or a database (`remote-data.md`).
- `library(duckplyr)` replaces dplyr verbs for **all** data frames in the session. Use `duckplyr::` calls or `duckplyr::methods_restore()` to keep it local.
- duckplyr optimizes only functions it can translate. `gsub()`, `sub()` and `grepl()` translated; `toupper()`, `nchar()`, `paste0()`, `substr()` and `stringr::str_replace_all()` did not. With `prudence = "stingy"` that is an error; with the default it silently falls back to dplyr, without the optimizer. dbplyr translates `str_replace_all()`/`str_detect()` but passes `gsub()` through to SQL, where it fails.

## How to check

``` r
identical(arrange(old_pipeline(x), id), arrange(new_pipeline(x), id))
bench::mark(old_pipeline(x), new_pipeline(x), check = FALSE)
dplyr::explain(lazy_query)      # duckplyr / dbplyr: look for Filters and Projections in the scan
```

## Traps

- A filter moved before a join changes results if it tests a column the join creates or fills (e.g. `NA` from a left join). Check that the filter uses only columns that exist before the join with the same values.
- Moving `distinct()` earlier is exact only if the expensive function is element-wise and pure.
- Sorting differences: grouped results may come back in a different order; compare after sorting.
- An early `select()` that drops a column a later step needs fails loudly, which is fine; one that drops an ID column needed to join back fails silently in logic. Keep keys.
