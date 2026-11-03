# Diagnose: read the profile, find hidden costs, predict


**When this matters.** Always, first. Before changing code, know where the time goes, what share of it any change could remove, and what you expect a change to do. The scripts below are read-only unless stated; they never build targets.

## The scripts, in order

| Step | Script | Answers |
|----|----|----|
| 1 | `check_versions.R` | Do installed versions match the ones this skill was tested with? |
| 2 | `machine_profile.R [dir]` | Cores, *available* memory, container limits, thread defaults, BLAS, OpenMP builds, `/dev/shm`, disk, CLI download tools |
| 3 | `tar_profile.R [store=_targets] [n=20] script=_targets.R measure=a,b` | Slowest and largest targets, branch statistics, big objects with many downstream targets, hidden save/load time |
| 4 | `tar_dag.R workers=1,2,4,8 [outdated=TRUE] [overhead=s]` | Critical path, width, maximum useful speedup, predicted wall time per worker count |
| 5 | `startup_cost.R [script=] [reps=]` | What each new worker pays: R, `.Rprofile`, packages |
| 6 | `profile_pipeline.R out=<dir> top=10` (runs code: ask) then `profile_summary.R <dir>/profiles` | Where inside each slow target the time goes; functions slow across many targets |

Run them from the project root with the project's R (`Rscript path/to/scripts/<name>.R ...`).

## Reading `tar_profile.R`

- **Top by seconds.** `tar_meta()` seconds time the command only. A target at 30% of total seconds caps any gain elsewhere at 70%.
- **Top by bytes.** Big objects cost save and load time and memory per reader.
- **Branched targets.** Many branches with tiny medians mean overhead dominates (`branching.md`). A pattern's total is the sum of its branches; with workers they overlap.
- **Big objects with ≥ 3 direct downstream targets.** Candidates for partial reads, splitting, or sharing (`storage-formats.md`, `sharing-mori.md`).
- **Hidden I/O.** Estimated save time, time per read, and total load time from stored bytes and measured format throughput (`format-throughput.csv`). `downstream` counts direct downstream targets (as in `tar_dag.R`); `loads` counts each branch of a dynamic-branching reader once, which is what worker retrieval pays (the default `retrieval = "auto"` loads a target that a pattern maps over once, in main). Calibrate with `measure=name`, which times one real `tar_read()`: shared-memory formats, custom formats and character-heavy tables can load slower than the estimate.

Why the hidden part matters: saving a 61 MB table as `rds` took 4.4 s of `tar_make()` wall time while `tar_meta()` recorded 0 s. Throughput differs by format and object: for a numeric table, qs2 (1 thread) saved at 306 MB/s vs 17 MB/s for `rds`; for a character table 78 vs 15 MB/s. Source: benchmark results `storage/targets_store.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

## Reading `tar_dag.R`

- **Max useful speedup = total seconds / critical path.** If it is 1.7x, no worker count beats 1.7x; the only lever is the critical path itself (speed up or split its slowest target).
- **Width by level** and **ideal-schedule concurrency**: how many targets could ever run at once. More workers than that only add memory.
- **Fan-out of big objects**: MB × direct downstream targets, the load cost parallel consumers will pay.
- **Predicted wall time** per worker count, from last build times: a simulated schedule that starts each ready target (or branch) on the next free worker, longest remaining chain first. `outdated=TRUE` predicts only what `tar_make()` would rebuild now.

Calibrating `overhead=` (seconds added per dispatched task): from the benchmarks, per-target overhead was about 6.0 ms serial and 15.6 ms through a crew worker, and starting workers cost roughly 3.0 s once per build. Source: benchmark results `targets_mech/c1_nproc.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`). Use `overhead=0.016` for crew builds of many small targets; add the start-up once.

## Predict before running

State expected numbers before every run, benchmark or structural change; compare afterwards and explain any gap. A gap is information: it usually points at a hidden cost or a wrong assumption.

| Prediction | From |
|----|----|
| Rebuild time of outdated targets | `tar_dag.R outdated=TRUE workers=1` |
| Wall time with N workers | `tar_dag.R workers=N overhead=<per-task overhead above>` + worker start-up |
| Peak memory | main + N × (largest inputs loaded + intermediates) per target; `tar_profile.R` bytes; compare with available memory (`memory.md`) |
| Benchmark run time | time the subset at small n, scale linearly (or by n log n for sorts), then multiply by iterations |
| Gain from a rewrite | target seconds × (1 − 1 / measured speedup on a subset) |

Typical reasons for a gap: save/load time (not in `tar_meta`), worker start-up, data shipped to workers under `retrieval = "main"`, thread oversubscription, a target whose last build time was from a different input size, other load on the machine, and a cold file or network cache.

## Classify the bottleneck

Match what the scripts and profiles show to the **symptom → strategy → reference** table in the skill's `SKILL.md` (step e). Keep that table as the single list; it names the profile functions (`lapply`, `gsub`, `%*%`, ...) that point to each bottleneck.

## Benchmark on subsets

Do not rebuild the pipeline to test a rewrite. Load real inputs with `tar_read()`, take a subset large enough to be representative (most speedups depend on n: see the crossovers in `fast-functions.md`), and compare:

``` r
x <- targets::tar_read(input)[1:1e5, ]
bench::mark(old = old_fun(x), new = new_fun(x), check = FALSE, iterations = 10, filter_gc = FALSE)
identical(old_fun(x), new_fun(x))
```

Report ratios, not absolute times (other load on the machine shifts absolutes). Then check identity on the **full** real input: some traps (windowed regex, case folding, duplicate join keys) only appear at scale. If an `r-performance` skill is available, follow it for profiling with profvis and `bench::mark()`.

## Regression check

``` sh
Rscript scripts/tar_snapshot.R save /tmp/snap store=_targets target_a target_b   # before
# ... change code, rebuild the affected targets (with approval) ...
Rscript scripts/tar_snapshot.R compare /tmp/snap store=_targets                  # exit 1 if anything differs
```

`compare` reports `identical()` per target and md5 changes of file targets. Values that differ only in environments (formulas and terms in `lm`/`glm` fits, closures) are reported as `EQUAL (environments differ)` and pass; data are still compared exactly. For a real difference it prints the first `waldo` differences. Trace any difference to rows (`which(a != b)`, `waldo::compare()`): in the case study this exposed a real data issue. File outputs that embed a timestamp (e.g. xlsx) always differ; compare their contents.

## Traps

- `tar_meta()` rows update only when a target completes; stale branch rows stay until `tar_prune()` (the scripts use each pattern's current children).
- Last build times reflect the last input size and machine load.
- `profile_pipeline.R` runs pipeline code on a copy of the store, skipping file, URL and `*_deployed` targets. It still runs code: get approval, and check for targets with side effects first.
