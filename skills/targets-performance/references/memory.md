# Memory: settings, budgets and limits


**When this matters.** A parallel build is killed, swaps, or slows down as it runs; or a big object is read by many targets and each read costs seconds. The knobs are `memory`, `retrieval`, `storage`, `deployment` and `garbage_collection` in `tar_option_set()` / `tar_target()`, plus the worker count. The budget that matters is **available** memory, which is often far less than physical RAM because other processes share the machine.

## What the settings do (targets ≥ 1.11)

- `memory = "auto"` (default) behaves as `"transient"` for ordinary targets: a target's value is dropped after use and read from the store again by the next consumer. It is persistent only for non-dynamic targets that other targets dynamically branch over.
- `storage = "worker"` (default): each worker saves its own output.
- `retrieval = "auto"` (default): acts as `"worker"` (each worker reads its inputs from the store) except when a dynamic branch maps over a non-dynamic target. Then it acts as `"main"`: main loads that target once (kept, since `memory = "auto"` makes it persistent) and sends each branch only its slice. For ordinary (static) consumers of a big object, `memory` therefore makes little difference: every consumer reads from disk.
- `retrieval = "main"`: the main process loads the input and sends it to the worker over the network connection. With `memory = "persistent"` in a serial run this avoids repeated reads; under crew it costs a copy per in-flight task in the main process.
- `deployment = "main"`: run the target in the main process. Good for tiny targets and for consumers of a big object that is already in main memory.
- `garbage_collection`: an integer since targets 1.9 (default 0 since 1.11); `gc()` runs every N targets on each worker, and `TRUE` means 1. Target-level `garbage_collection = TRUE` runs `gc()` before that one target.

## Measured: one 300 MB object, six consumers

| setup | reads of big | wall | peak memory (process tree) |
|:---|:---|:---|:---|
| serial, defaults (auto memory, auto retrieval) | 6 | 5.1 s | 1.7 GB |
| serial, transient, worker retrieval | 6 | 5.8 s | 1.7 GB |
| serial, persistent, worker retrieval | 6 | 5.8 s | 2.1 GB |
| serial, persistent, **main retrieval** | 0 | 3.1 s | 1.6 GB |
| 3 workers, defaults | 6 | 5.3 s | 3.3 GB |
| 3 workers, transient, worker retrieval | 6 | 6.3 s | 3.1 GB |
| 3 workers, persistent, main retrieval | \- | killed at memory cap | 4.2 GB |

Source: benchmark results `targets_mech/c3_memory.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). Peak memory sums RSS over the R process tree, including workers; for killed runs it is the peak when the run was killed (a lower bound).

Read it as:

- The defaults behaved like worker retrieval (6 reads serially, 6 with 3 workers): these consumers are not dynamic branches, so `"auto"` does not act as `"main"`. They were up to about a second faster than the worker rows; these are single runs from a separate session, so that is likely noise. The reads are the same.
- `persistent` alone changed nothing (still 6 reads) because worker retrieval re-reads from the store. Only persistent **plus** explicit `retrieval = "main"` avoided the reads in a serial run.
- With 3 workers, main retrieval of a 300 MB object was killed at the benchmark's memory cap (at 4.2 GB or more): main holds the object plus a serialized copy for each task in flight. At 100 MB it fit, at 2.2 GB vs 1.3 GB with worker retrieval.
- Under crew, keep worker storage and retrieval for big objects read by ordinary (static) consumers; for patterns that map over a big target, the default `"auto"` is better (`branching.md`). To stop repeated reads, use partial reads (`storage-formats.md`), split the object, or share it (`sharing-mori.md`).

`garbage_collection = 0`, 1 or 10 made no measurable difference to wall time (5.9 s, 6.0 s, 5.8 s) or peak memory: R already collects when it allocates large vectors. Leave it at 0 unless a target keeps big intermediates alive; then set target-level `garbage_collection = TRUE` on that target. Source: benchmark results `targets_mech/c4_gc.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`).

## The budget

Predict before you parallelize:

> peak ≈ main process + workers × (largest inputs a target loads + its intermediates + output) + any copies made by main retrieval or sharing

- Each crew worker started at a few hundred MB (R + targets + crew + packages) before loading data; see `parallelism.md`.
- Compare the budget with **available** memory (`machine_profile.R`), not total RAM, and leave headroom for the rest of the machine.
- In containers, the limit is the cgroup `memory.max`; `ps::ps_system_memory()` and `/proc/meminfo` report the host. `machine_profile.R` prints both.
- Library defaults assume they own the machine: duckdb's `memory_limit` defaults to 80% of RAM *per process*, so four duckdb workers each believe they may use most of the memory. Set it per worker (about half the container limit, or 0.6 × available / workers). In a 2 GB container, a duckdb query that spills to disk completed in 1 of 5 runs with the default limit (3 OOM-killed, 1 stalled) and in 2 of 2 with `memory_limit = '1GB'`. Source: benchmark results `docker/b7_duckdb_spill.csv` (Linux aarch64, R 4.6.2; run 2026-11-03).
- Reading a character-heavy table can take much more memory than `object.size()` reports before saving; budget from the serialized size and a measured read (`tar_profile.R measure=`).

When over budget: fewer workers for the memory-heavy part (a separate small controller in a `crew_controller_group()`), partial reads, smaller upstream targets (filter and select early: `query-order.md`), or shared memory for a big read-only object.

## Monitoring a run

- crew and mirai workers are detached from the session's process tree; a session's own RSS misses them. Watch system available memory or sum RSS over all R processes (`ps::ps()` filtered on name).
- `tar_meta()` has no memory field. For per-target memory, profile with `profile_pipeline.R memory=TRUE` (allocations) or run the target alone and watch RSS.
- Run one heavy benchmark or build at a time on a shared machine.

## Traps

- `memory = "persistent"` with worker or default (`"auto"`) retrieval does not prevent reads by ordinary consumers; it only keeps copies in memory longer.
- Main retrieval multiplies memory by the number of tasks in flight.
- With `retrieval = "worker"`, dynamic branches over a big stored table load the whole table in every branch. The default `"auto"` loads it once in main instead, so main must hold it (`branching.md`).
- `/dev/shm` in Docker defaults to 64 MB; shared-memory objects need `--shm-size` (`sharing-mori.md`).
- Older targets (\< 1.11) had other defaults (e.g. `garbage_collection` 1000 in the book); check `targets::tar_option_get()` rather than trusting old advice.
