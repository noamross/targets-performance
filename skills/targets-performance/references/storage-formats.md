# Storage formats


**When this matters.** `tar_profile.R` shows big targets in `rds` format, a large share of build time that is not in `tar_meta()` seconds, or big objects read by many targets. Saving and loading are hidden costs: `tar_meta()$seconds` times the command only. In a test the save of a 53 MB target showed 0 s in `tar_meta()` while `tar_make()` took 1.1 s.

## The default: `format = "qs"`

Since targets 1.9, `format = "qs"` uses qs2. It stores any R object and is much faster than the default `rds` (gzip):

| object | rds gzip write | qs2 1 thread | qs2 4 threads | rds / qs2 4t | read rds | read qs2 1t | MB rds / qs2 |
|:---|:---|:---|:---|:---|:---|:---|:---|
| numeric data frame, 1e7 x 10 | 24 s | 1.2 s | 395 ms | 61x | 1.3 s | 436 ms | 408 / 376 |
| character-heavy tibble, 1e6 rows | 19 s | 3.2 s | 900 ms | 21x | 3.2 s | 1.9 s | 292 / 251 |

Source: benchmark results `storage/storage.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-02, 2026-11-03).

Inside a pipeline the same holds: saving a 61 MB text table took 4.4 s as `rds`, 1.1 s as `qs` and 592 ms with `tar_resources_qs(nthreads = 4)`. Every load pays the read side of this too, once per downstream target under worker retrieval (`branching.md`, `memory.md`).

**Threads.** qs2 threads help big flat buffers and hurt small ones. On a list of 1e5 small data frames, reading with 4 threads took 350 ms vs 101 ms with 1. Use `tar_resources_qs(nthreads = k)` on the few big targets when cores are free, and 1 thread inside parallel workers (see `parallelism.md`). Multi-threaded qs2 needs a build with TBB (Intel's Threading Building Blocks library, which RcppParallel provides); without it, it warns and uses 1 thread.

**Compression.** Random doubles barely compress (matrix of 191 MB uncompressed vs 168 MB in qs2). Compression level is rarely worth tuning.

## What each format loses

`identical()` after a round trip, by object feature:

| feature | rds | qs2 | zap | qd | nanoparquet | arrow | duckdb |
|:---|:---|:---|:---|:---|:---|:---|:---|
| df_rownames_attrs | identical | identical | identical | identical | lossy | lossy | lossy |
| tibble | identical | identical | identical | identical | lossy | identical | lossy |
| list_col | identical | identical | identical | identical | ERROR | ERROR | ERROR |
| grouped_df | identical | identical | identical | identical | lossy | identical | lossy |
| difftime_cplx_raw | identical | identical | identical | identical | ERROR | ERROR | ERROR |
| named_list | identical | identical | identical | identical | ERROR | ERROR | lossy |
| s4_object | identical | identical | identical | lossy | ERROR | ERROR | ERROR |
| formula | identical | identical | identical | lossy | ERROR | ERROR | ERROR |
| closure | identical | identical | identical | lossy | ERROR | ERROR | ERROR |
| environment | lossy | lossy | lossy | lossy | ERROR | ERROR | ERROR |

Source: benchmark results `storage/fidelity.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). "lossy" = round trip not identical (class, row names, attributes or types changed); `ERROR` = cannot store.

- **qd** (`qs2::qd_save`) replaces functions, environments, formulas and S4 objects with `NULL` (warning once per object type per session). A fitted model lost its closure and environment members. It was not faster than `qs_save` here (1.2 s vs 1.2 s on the numeric table), and its ALTREP string reading (lazy, deferred materialization of character vectors) is disabled in qs2 0.3.1. No reason to use it in a pipeline.
- **nanoparquet** returns a `tbl`, drops row names and attributes, turns ordered factors into factors, and cannot store list columns of data frames, complex or raw.
- **arrow** keeps tibble, grouped_df, factor, Date and time zone (it stores R metadata) but turns a plain data.frame into a tibble.
- **duckdb** returns factors as character.
- **zap** (GitHub only, needs R ≥ 4.5; its current release needed a patch to build on R 4.6) round-trips everything qs2 does with slightly smaller files; keep it experimental.
- **fst** failed to load on the macOS test machine (OpenMP symbol missing); no numbers.

## Parquet: partial reads

Parquet pays when downstream targets need a few columns or rows of a big table. A full read is no faster than qs2; the gains come from not reading:

| read | parquet partial | reader | full read then subset |
|:---|:---|:---|:---|
| 2 of 10 columns | 18 ms | arrow `col_select` | 40 ms |
| 2 of 5 columns, text table | 764 µs | nanoparquet `col_select` | 168 ms |
| 1% of rows, file sorted by filter column | 10 ms | arrow `open_dataset() \|> filter()` | 155 ms |
| 1% of rows, unsorted file | 130 ms | duckdb `WHERE` | 190 ms |

Source: benchmark results `storage/storage.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-02, 2026-11-03). Table of 2.5e6 rows x 10 columns; text table 1.5e5 rows.

Memory matters more than time. Peak RSS above baseline when reading 2 columns: nanoparquet 38 MB, arrow 98 MB, duckdb 120 MB, vs 235 MB for a full qs2 read. A full arrow read peaked at 390 MB vs 235 MB for qs2: arrow builds a Table, then converts. Source: benchmark results `storage/storage_rss.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

Row filters only skip data when the file is **sorted by the filter column** (row-group min/max statistics); on unsorted data every row group must be read. Sorted, duckdb was 7.6x faster than unsorted. Default row groups (122,880 rows) worked as well as 10,000; 1e6-row groups pruned less.

## Partial loads in a pipeline

Three ways to let a consumer read part of a big table:

1.  **`format = "file"` parquet target** (simplest): the command writes `data/big.parquet` and returns the path; consumers read with `col_select` or duckdb. Dependencies work naturally; you manage the file's location.

2.  **Store format parquet + `retrieval = "none"`**: keep the target in the store and read it in place.

    ``` r
    tar_target(big, make_big(), format = tarchetypes::tar_format_nanoparquet())
    tar_target(
      two_cols,
      nanoparquet::read_parquet(
        tar_path_target(big, store = tar_path_store()),  # symbol `big` declares the dependency; never evaluated
        col_select = c("x1", "x2")
      ),
      retrieval = "none"
    )
    ```

    Serial, this cut the consumer's peak RSS from 578 MB to 291 MB for a 300 MB table. With 3 crew workers: 764 MB vs 1.8 GB (normal worker retrieval) vs 4.5 GB (main retrieval). A `format = "file"` target gave the same 291 MB. Source: benchmark results `targets_mech/c9_partial.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

3.  **Split the object** into the column sets consumers need (upstream targets).

A qs2 target cannot be read partially: `retrieval = "none"` + `qs_read()` only moves the full read into the command.

## Choosing

| Object | Format |
|----|----|
| Anything (models, lists, closures, S4) | `"qs"`; `tar_resources_qs(nthreads = k)` on big targets when cores are free |
| Big data frame read whole | `"qs"`; parquet only for interop |
| Big data frame, consumers need few columns or rows | parquet (`tar_format_nanoparquet()`, `format = "file"`), sorted by the main filter column |
| Larger than available memory | `format = "file"` parquet (or a partitioned directory), read with duckdb with `memory_limit` set |
| List columns of data frames | `"qs"` (arrow reads them back slowly; nanoparquet cannot write them) |
| Lazy tables, connections, Arrow Datasets | never a target value; open them inside the command |
| Shared across parallel readers | see `sharing-mori.md` |

Changing a target's format invalidates it and everything downstream once. `tar_format()` read/write functions must be self-contained (namespace every call, helpers inside the function).

## Traps

- `tar_meta()$seconds` excludes saving; estimate it from bytes (`tar_profile.R` does) or time `tar_make()`.
- nanoparquet's zstd default produced larger files than snappy on these data (866 MB vs 430 MB on text); check sizes before choosing.
- `arrow::set_io_thread_count(1)` can hang reads; for single-threaded arrow use `set_cpu_count(1)` only. Single-threaded arrow reads were several times slower; nanoparquet is single-threaded by design and fast.
- Character tables use more memory once read than `object.size()` suggests (strings materialize); budget from the serialized size.
- `tar_path_target(big)` without `store = tar_path_store()` points to the default store even when `tar_make(store = )` uses another one. `tar_read()` inside a command errors. A hard-coded store path has no dependency edge.
- Parquet files cannot be appended (arrow). Cloud-store targets have no local file; use `format = "file"`.
