# Remote data: parquet over HTTP/S3 and downloads


**When this matters.** Targets read parquet files from object storage (S3, R2, GCS) or plain HTTPS, or the pipeline downloads many files. Remote reads are bound by requests and bytes, not CPU, so the levers are: read fewer bytes (columns, partitions, sorted row groups), reuse what was fetched (caches, one connection per process), and decide when to download the whole file instead.

The measurements use a public test file, `blobs.duckdb.org/flight-data-partitioned/Year=2024/data_0.parquet` (201 MB, 110 columns, sorted by date[^1]), over a home connection with duckdb 2.0.0. Seconds are single runs and noisy; bytes are exact (from duckdb's HTTP log).

## Read fewer bytes

| query                                               | MB fetched | seconds |
|:----------------------------------------------------|:-----------|:--------|
| 3 columns, row filter                               | 11 MB      | 2.9 s   |
| 20 columns, row filter                              | 44 MB      | 2.5 s   |
| all 110 columns, row filter                         | 191 MB     | 30 s    |
| `count(*)` only                                     | 1.3 MB     | 1.3 s   |
| 2 yearly files, filter on the hive partition `Year` | 12 MB      | 3.0 s   |
| same, no partition filter                           | 97 MB      | 5.4 s   |
| filter on the sorted column (one day)               | 3.0 MB     | 1.7 s   |
| filter on an unsorted column                        | 11 MB      | 2.2 s   |

Source: benchmark results `remote/b12.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

1.  **Select columns before `collect()`.** Parquet stores columns separately; a narrow query fetches only those column chunks. `SELECT *` on a wide remote file downloads nearly all of it, through many small requests.
2.  **Filter on partition columns with literal values.** With hive paths (`Year=2024/`), a partition filter skips other files' data, but duckdb still reads each listed file's footer. Pass an explicit list of URLs for the partitions you need; plain HTTPS cannot glob.
3.  **Row filters save bytes only on sorted (clustered) columns.** Row-group min/max statistics let duckdb skip row groups when the data are sorted by the filter column; on an unsorted column the whole column is read. When you write parquet for later remote reads, sort by the main filter column.
4.  **Collect only the filtered subset, once, into a target** (`qs` or parquet). Downstream targets then read locally (`query-order.md`).

## Reuse what was fetched

| case                                         | MB fetched | seconds |
|:---------------------------------------------|:-----------|:--------|
| cold query, external file cache on (default) | 11 MB      | 1.7 s   |
| same query again, same session               | 0.0 MB     | 368 ms  |
| other columns, same file, same session       | 7.5 MB     | 673 ms  |
| cache off: same query again                  | 11 MB      | 1.9 s   |
| cache_httpfs, first session (cold)           | 83 MB      | 2.7 s   |
| cache_httpfs, new R session (warm)           | 0.0 MB     | 660 ms  |

Source: benchmark results `remote/b3.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

- **duckdb caches remote reads in memory by default** (`enable_external_file_cache`, since duckdb 1.3.0[^2]): a repeated query in the same session fetched nothing, and a query on other columns of the same file fetched only the missing chunks. Measured on 2.0.0 only. Upgrading from 1.3.x does not add this cache; duckdb older than 1.3.0 lacks it.
- `enable_http_metadata_cache` and `parquet_metadata_cache` (off by default) trimmed only HEAD and footer requests here; not worth turning on next to the external file cache.
- **cache_httpfs** (community extension; version 0.15.0 loaded on duckdb 2.0.0) keeps a disk cache across sessions. It fetches in large blocks, so a cold sparse query downloaded several times more than needed (83 MB vs 11 MB). Use it for repeated sessions over the same immutable files. It does not notice an overwritten object (clear with `SELECT cache_httpfs_clear_cache()`), and its glob cache can hide new files[^3].
- **One connection per process.** 20 remote `count(*)` calls took 19 s with a new connection each time and 6.9 s with one memoized connection. Opening the connection itself was cheap (355 ms for 20); the loss is the cache. Source: benchmark results `remote/b67.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

A memoized connection, created inside targets (never returned as a target value):

``` r
get_con <- local({
  con <- NULL
  function(threads = NULL, memory_limit = NULL) {
    if (is.null(con) || !DBI::dbIsValid(con)) {
      cfg <- Filter(Negate(is.null), list(threads = threads, memory_limit = memory_limit))
      con <<- DBI::dbConnect(duckdb::duckdb(config = cfg))
      DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
      DBI::dbExecute(con, "SET http_retries = 6; SET http_retry_wait_ms = 500;")
      # S3/R2: CREATE SECRET with KEY_ID getenv('...'), never paste key values into SQL strings
    }
    con
  }
})
```

Each crew worker builds its own connection; set `threads` and `memory_limit` per worker (`parallelism.md`, `memory.md`). For remote scans keep several threads: 1 thread fetched 47 MB in 4.0 s vs 11 MB in 2.2 s with 12, because fewer threads made coarser reads.

## Download once or read remotely?

| columns        | remote query | local query after download | break-even queries |
|:---------------|:-------------|:---------------------------|:-------------------|
| 3 cols         | 2.5 s        | 48 ms                      | 1.4                |
| 20 cols        | 2.4 s        | 154 ms                     | 1.4                |
| all cols (110) | 22 s         | 811 ms                     | 0.2                |

Source: benchmark results `remote/b4.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). Whole-file download: 3.3 s with `curl::multi_download()`. Break-even = download time / (remote − local) per query.

Rule: one narrow query, read remotely; two or more queries, or a large share of the columns, download once (as a `format = "file"` target) and query locally. The break-even scales with link speed and file size: on a slow link or a multi-GB file, narrow remote reads win for more queries.

## Front ends

- duckplyr `read_parquet_duckdb(url, prudence = "stingy")` and dbplyr on your own duckdb connection gave the same plan and result (1.7 s and 2.4 s cold). "Stingy" makes duckplyr error rather than silently pull a large table into R; end with `collect()` or `compute_parquet()`.

- duckplyr uses its own default connection: configure it with `duckplyr::db_exec()` (extensions, secrets, cache). dbplyr uses the connection you configured.

- arrow: `open_dataset("https://...")` failed (no HTTPS filesystem); `arrow::read_parquet(url)` worked but took 3.8 s and again 4.1 s on repeat, about a full download each time. Use duckdb for remote parquet; arrow datasets work against S3-compatible stores via `s3_bucket()`.

- DuckLake catalogs (a small catalog database plus parquet files) prune files from catalog statistics without listing; DuckLake 1.1 needs duckdb ≥ 2.0[^4]. A local catalog is one database file plus a data directory[^5]; a minimal recipe (not benchmarked here):

  ``` r
  con <- DBI::dbConnect(duckdb::duckdb())
  DBI::dbExecute(con, "INSTALL ducklake; LOAD ducklake;")
  DBI::dbExecute(con, "ATTACH 'ducklake:lake.ducklake' AS lake (DATA_PATH 'lake_data/')")
  DBI::dbExecute(con, "CREATE TABLE lake.flights AS SELECT * FROM read_parquet('https://.../*.parquet')")
  # later sessions: ATTACH again, then query lake.flights; filters prune files from catalog statistics
  ```

  Keep the catalog and data directory outside the `{targets}` store and track them with a file target, or fetch into the catalog in one explicit target.

## Downloading many files

| Need | Tool |
|----|----|
| Many files, no extra packages | `download.file(urls, destfiles, method = "libcurl")`: simultaneous; `method = "libcurl"` must be given explicitly; check `attr(res, "retvals")` per file[^6] |
| Many files, resumable | `curl::multi_download(urls, destfiles, resume = TRUE)`; returns a status table |
| Many API calls, pipeline already uses httr2 | `httr2::req_perform_parallel(reqs, max_active = )` with `req_throttle()` and `req_retry()`[^7] |
| Custom handlers | `curl::curl_fetch_multi()` with a `new_pool(host_con = )`[^8] |
| One huge file | `aria2c -x4 -s4` (parallel ranges; measured 1.2 s vs 3.3 s for curl on one run, so not a reliable win for a single file); verify a checksum |
| One huge file, R only | ranged requests: one `curl::new_handle(range = "<from>-<to>")` per part in `curl_fetch_multi()`, then concatenate the parts in order and verify a checksum. Not tested here. |
| Crawling a site | `wget -m -np --wait=1 --random-wait`; respects robots.txt |

In the pipeline:

- Make network fetches explicit targets with a refresh policy (`tarchetypes::tar_age()`, or a force cue from an environment variable), so code edits do not re-fetch. Track a remote file with `format = "url"` (needs an ETag or Last-Modified header) or `tarchetypes::tar_download()`.
- Put each rate-limited host on its own one-worker crew controller in a `crew_controller_group()`, and pin its fetch targets with `tar_resources_crew(controller = )`; other targets keep the main pool.
- Retry at two levels: duckdb `http_retries` / `http_retry_wait_ms` (defaults 3 and 100 ms[^9]) and an R-level retry around `collect()` for transient network errors.

## How to measure

``` sql
CALL enable_logging('HTTP');
-- run the query, then:
SELECT count(*) AS requests FROM duckdb_logs WHERE type = 'HTTP';
```

Sum the response `Content-Length` of GET requests for bytes; `EXPLAIN` shows which filters and columns reached the parquet scan. duckdb 2.0 removed the older `enable_http_logging` setting.

## Traps

- `union_by_name = true` over many remote files reads every file's schema up front.
- Parquet files with few, huge row groups cannot use many threads or skip much.
- Never interpolate secret values into SQL strings (they appear in logs and error messages); use `getenv()` inside `CREATE SECRET`.
- A remote object replaced under the same name is invisible to cache_httpfs until you clear its cache.
- Connections and lazy tables are external pointers: never store them as target values.
- Not tested here: duckdb 1.x behaviour, S3/R2 with credentials, arrow on S3.

[^1]: Source: <https://blobs.duckdb.org/flight-data-partitioned/Year=2024/data_0.parquet> (retrieved 2026-11-02; content-length on HEAD).

[^2]: Source: <https://duckdb.org/2025/05/21/announcing-duckdb-130.html> (retrieved 2026-11-03; New Features \> External File Cache: "With this release, we added a cache for data from external files." ... "The cache is enabled by default").

[^3]: Source: <https://github.com/dentiny/duck-read-cache-fs/blob/main/README.md> (retrieved 2026-11-02; Caveat section).

[^4]: Source: <https://ducklake.select/docs/stable/duckdb/introduction> (retrieved 2026-11-02; DuckLake 1.1 requires DuckDB 2.0.0 or later).

[^5]: Source: <https://ducklake.select/docs/stable/duckdb/usage/paths> (retrieved 2026-11-02; Default Path Structure).

[^6]: Source: R 4.6.2 help page ?utils::download.file (retrieved 2026-11-03; Arguments section (url) and Value section).

[^7]: Source: <https://httr2.r-lib.org/reference/req_perform_parallel.html> (retrieved 2026-11-03; Usage: max_active = 10; Limitations: "This makes it most suitable for performing many parallel requests to the same host"; "it does not respect the max_tries argument to req_retry()").

[^8]: Source: <https://jeroen.r-universe.dev/curl/doc/manual.html> (retrieved 2026-11-03; total_con: max total concurrent connections; host_con: max concurrent connections per host).

[^9]: Source: <https://duckdb.org/docs/2.0/configuration/overview.html> (retrieved 2026-11-02; http_retries).
