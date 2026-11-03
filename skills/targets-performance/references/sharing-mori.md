# Sharing a big object across parallel targets (mori)


**When this matters.** One big read-only object (hundreds of MB or more) is read by several targets that run in parallel, and either the build does not fit in memory or each consumer spends seconds loading it. [mori](https://cran.r-project.org/package=mori) puts the object in shared memory once; workers on the same machine map it instead of copying it. In the benchmarks the gain was **memory, not speed**.

## Measured

Three crew workers, six consumers of one object:

| setup                             | wall   | peak memory (tree sum) |
|:----------------------------------|:-------|:-----------------------|
| 100 MB, no mori, worker retrieval | 7.0 s  | 3.1 GB                 |
| 100 MB, no mori, main retrieval   | 6.8 s  | 3.1 GB                 |
| 100 MB, mori (`format_qs_shared`) | 6.9 s  | 1.9 GB                 |
| 300 MB, no mori, worker retrieval | killed | 4.7 GB                 |
| 300 MB, no mori, main retrieval   | killed | 5.0 GB                 |
| 300 MB, mori                      | 6.9 s  | 4.2 GB                 |

Source: benchmark results `targets_mech/c5_mori.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). The tree sum counts shared pages once per process that maps them, so it overstates mori's real use; "killed" = killed at the benchmark's memory cap (peak 4.7 GB or more). Consumers here are ordinary (static) targets, so the default `retrieval = "auto"` acts as worker retrieval.

A second `tar_make()` with everything up to date skipped all targets (0 completed): the shared format does not invalidate downstream targets.

## How to use it

`scripts/formats.R` defines the formats. Source it in `_targets.R`.

``` r
source("path/to/targets-performance/scripts/formats.R")
tar_option_set(format = format_qs_unshared)   # every other target: safe to save shared columns
list(
  tar_target(big, mori::share(make_big()), format = format_qs_shared,
             memory = "persistent", deployment = "main", storage = "main", retrieval = "main"),
  tar_target(a, summarise_a(big), retrieval = "main"),  # workers receive only the region name
  tar_target(b, summarise_b(big), retrieval = "main")
)
```

- `format_qs_shared` writes real data (`rlang::duplicate()` then `qs2::qs_save()`) and re-shares on read, so the store stays valid across sessions.
- `format_qs_unshared` copies any shared vector inside an object before saving. Use it as the default format: `dplyr::mutate(big, z = 1)` keeps the untouched shared columns, and saving them with a plain writer stores only the region name.
- Parquet variants: `format_parquet_shared` / `format_parquet_unshared` (parquet writes values, so no copy is needed).

## Where the copies are

- **Build run:** `share()` copies the object into shared memory; the write makes one more copy (`duplicate`) before saving.
- **Later runs** (big up to date, consumers outdated): read from disk, then `share()`: about twice the object at peak, and the load is slower than a plain read.
- **Per consumer:** only the region name crosses to the worker.

It pays when (readers in parallel × per-reader load or copy) exceeds one share copy, and when the object would not fit once per worker.

## Alternatives, often simpler

| layout                                                   | wall  | peak memory |
|:---------------------------------------------------------|:------|:------------|
| shared format (above)                                    | 4.7 s | 1.5 GB      |
| plain object, `marshal = mori::share`                    | 4.6 s | 1.9 GB      |
| no mori: big persistent, consumers `deployment = "main"` | 7.6 s | 731 MB      |
| no mori: `retrieval = "worker"`                          | 5.7 s | 1.5 GB      |

Source: benchmark results `targets_mech/c5b_mori_marshal.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). 100 MB object, 3 workers, 6 consumers, first repetition.

- **Consumers in main** (`deployment = "main"`, big persistent): least memory, no copies, but consumers run one at a time. Best when consumers are short and the parallel work is elsewhere in the DAG.
- **Worker retrieval** (what the default `"auto"` does for ordinary consumers): simplest; fine up to roughly 100 MB objects and a few readers if memory allows workers × object.
- **Marshal-based sharing** (`tar_format(..., marshal = function(object) mori::share(object))`): targets calls `marshal` once per consumer dispatch, so each dispatch makes a full share copy. Same wall time, more memory. Not recommended.
- **Don't load it at all**: partial parquet reads or a smaller upstream target (`storage-formats.md`).

## Traps

- **Never return `share()` from a target with a plain format.** qs2 and `saveRDS` write only the region name (a few hundred bytes; about 300 per transfer[^1]); a fresh session then fails with `mori: shared memory region not found`.
- **Never make a "shared" target with `cue = tar_cue("always")`.** The region name changes every run, so all downstream targets rebuild every time; with transient memory the pipeline errors.
- A big target built in main is not shared unless the command calls `mori::share()`.
- `tar_format()` functions run on workers: keep helpers inside them and namespace every call (as in `formats.R`).
- Same machine only. Consumers are read-only; modifying a shared vector makes a private full copy.
- Docker's default `/dev/shm` is 64 MB: `share()` of 100 MB failed with "cannot create region ... out of space" until the container ran with `--shm-size=1g`. Shared memory counts toward the container's memory limit.
- A crash can leave regions behind; `mori::prune_shared()` removes those of dead processes.
- Changing a target's format invalidates it and its downstream targets once.

[^1]: Source: <https://opensource.posit.co/blog/2026-04-23_mori-0-1-0/> (retrieved 2026-11-02; payload per daemon vs 200 MB).
