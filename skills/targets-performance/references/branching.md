# Branching and batching


**When this matters.** You are adding, removing or resizing branches; `tar_profile.R` flags many tiny branches; or branches read a big table. Branching is first a **design tool**: static branching (`tar_map()`) gives one named target per region, country or scenario, and dynamic branching (`pattern = map()`) gives one branch per file or key. Both make the pipeline readable and **cache at the branch level**: when one input changes, only its branch reruns. Speed is a third concern. Never add or remove branching for speed alone without weighing what it does to organization and incremental rebuilds.

## Branching does not speed up a serial run

Every branch is a target with its own bookkeeping, save and load. The same 5 s of work (1e4 rows at 0.5 ms each):

| setup                             | serial | 4 workers |
|:----------------------------------|:-------|:----------|
| one target                        | 5.9 s  | 7.2 s     |
| 10 branches                       | 5.9 s  | 3.9 s     |
| 100 branches                      | 6.1 s  | 3.8 s     |
| 1000 branches (list chunks)       | 10 s   | 6.1 s     |
| 1000 branches (`tar_group_count`) | 8.5 s  | 5.4 s     |

Source: benchmark results `targets_mech/c6_branching.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`).

- Serially, overhead was a few ms per branch: invisible at 100 branches, a large share at 1000 branches of 5 ms.
- With workers, branches are how one big job uses several cores. 10-100 branches gave the speedup; 1000 gave part of it back to overhead.
- Per-target overhead was similar for static and dynamic branching (`tar_map` vs `map()`: 17 s vs 17 s for 300 targets of 50 ms). Choose between them on design, not speed. Source: benchmark results `targets_mech/c7_static.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`).
- Under crew each target also pays a worker round trip, and the main process dispatches one target at a time (`parallelism.md`).

**Rule of thumb:** each branch should do at least 10-20 times the per-branch overhead (here about 4.5 ms serial with list chunks, 2.6 ms with `tar_group_count`), ideally half a second or more; use 2 to ~25 branches per worker. If the work is naturally tiny per item, batch it.

## Batching

Group tiny items into fewer branches. For replications, `tarchetypes::tar_rep(name, command, batches = B, reps = R)` runs R reps per batch; seeds do not depend on batching, so re-batching is safe. 1000 replications of 20 ms:

| batches | serial | 4 workers |
|--------:|:-------|:----------|
|    1000 | 24 s   | 9.5 s     |
|     100 | 23 s   | 7.7 s     |
|      40 | 22 s   | 7.3 s     |
|      10 | 22 s   | 8.3 s     |
|       4 | \-     | 7.8 s     |

Source: benchmark results `targets_mech/c6b_tar_rep.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`). Ideal: 20 s of work serially, 5 s on 4 workers, plus 1-2 s of start-up. Serial with 4 batches not run.

For data, chunk with `tarchetypes::tar_group_count()` / `tar_group_size()` (`iteration = "group"`), or a list target of chunks with `iteration = "list"`; `tar_group_count` had lower per-branch overhead than a list target. `tar_map_rep()` combines static parameters with batched replications. Batches = 2-10 × workers works when items cost about the same; use more when costs vary.

## Mapping over a big stored table

Four ways to run branches over one 200 MB table: map over the table itself (A, `iteration = "group"`), map over a list of chunks stored as one target (B), let each branch take the whole table as an ordinary dependency (C), or build each chunk as its own branch target and map over those (D). What A and B cost depends on `retrieval`:

| layout | reads, default (serial / 3 workers) | 3 workers wall, default | 3 workers peak, default | reads, worker (serial / 3 workers) | 3 workers wall, worker |
|:---|:---|:---|:---|:---|:---|
| A: map over group-iterated big table | 0 / 1 | 5.6 s | 2.4 GB | 6 / 7 | 7.1 s |
| B: map over list-of-chunks target | 0 / 1 | 5.6 s | 2.0 GB | 6 / 7 | 7.1 s |
| C: branches take whole table as dependency | 6 / 6 | 6.0 s | 3.5 GB | 6 / 6 | 6.4 s |
| D: each chunk built as its own branch target | 6 / 6 | 3.9 s | 1.4 GB | 6 / 6 | 4.2 s |

Source: benchmark results `targets_mech/c6c_bigmap.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). 200 MB table, 6 branches of 0.5 s. "Default" = `retrieval = "auto"` (targets ≥ 1.11); "worker" = `retrieval = "worker"`. Reads count whole-table loads (D: loads of the small chunks).

- **Default retrieval (A, B):** a pattern that maps over a stored non-dynamic target makes `"auto"` act as `"main"`: main loads the table once (it stays in memory, since `memory = "auto"` keeps it) and sends each branch only its slice. With 3 workers A took 5.6 s vs 7.1 s with worker retrieval. The cost moves to main, which must hold the whole table.
- **`retrieval = "worker"` (A, B):** every branch reads the whole object, then slices it. Avoid A and B with explicit worker retrieval.
- **C** reads the whole table in every branch under either setting: the branches do not map over it, so `"auto"` acts as `"worker"`.
- **D** was the fastest and lightest with 3 workers (3.9 s), because each branch builds and loads only its own chunk. Prefer it when the table is big relative to main's memory: a branch target per chunk (for example `pattern = map(ids)` producing each chunk), then map the work over those chunks.

## Organization and caching, with numbers that matter less

- Split a monolithic target when its inputs change independently (one file per year, one model per region): a change reruns one branch instead of the whole job.
- Keep a branch's identity stable (map over a key or file name, not row positions) so adding an item does not rebuild the others.
- Name static branches by their values (`tar_map(values = tibble(region = ...), names = region)`) so `tar_meta()` and `tar_visnetwork()` stay readable; combine with `tar_combine()`.
- Many thousands of branches slow the dependency check and the store (one file per branch: 1,003 targets for 1000 single-rep batches vs 13 for 10 batches).

## Traps

- More branches than workers × ~25 add overhead without speedup.
- `iteration = "list"` vs `"vector"`: vectors and data frames split by row with vctrs; non-vctrs objects need `"list"`.
- `format = "file"` branches store one file bundle per branch.
- Seeds: branches get their own seeds from their names; renaming branches changes random results.
- With crew, a branch that captures a big global object ships it to the worker every time; pass data as targets instead.
