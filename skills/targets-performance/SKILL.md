---
name: targets-performance
description: "Diagnose and speed up R {targets} pipelines. Profiles the store (slow and large targets, hidden save/load and worker start-up costs), the build graph (critical path, predicted wall time per worker count) and the machine (cores, available memory, container limits, threads, BLAS), then picks measured strategies (fast functions, vectorization, operation order, storage formats, memory settings, branching, crew parallelism, shared memory, remote parquet, downloads, BLAS), each with expected gain, output-identity risk and a regression check. Ships read-only scripts for the repeated steps. Use when a targets pipeline is slow, runs out of memory, or parallel builds disappoint. Keywords: targets, tar_make, tar_meta, crew, NPROC, mirai, mori, qs2, parquet, duckdb, duckplyr, collapse, data.table, kit, Rfast, stringi, vectorize, branching, tar_rep, BLAS, OpenBLAS, Accelerate, renv, profiling, benchmark."
argument-hint: "[path to targets project] [goal, e.g. 'halve wall time' or 'fit in 16 GB']"
---

## Environment

- **Local agent with R** (Claude Code, Codex, Positron Assistant), on Linux, macOS or Windows: everything below. Read cores, memory and limits from `machine_profile.R`; never assume them. Scripts run with the project's R: `Rscript <skill>/scripts/<name>.R ...` from the project root, where `<skill>` is the directory holding this file.
- **claude.ai or no R**: read the references and reason from pasted `tar_meta()` / `tar_manifest()` output; give the user the script commands to run and interpret what they paste back. Do not invent outputs.

## The method

Find where a {targets} pipeline spends its time and memory, predict what each change will buy, and make only the changes the user approves, each checked for identical output. Work in this order. Write each prediction down before the run that tests it.

**a. Versions and machine.** `check_versions.R` (installed vs tested package versions; stale advice warnings) and `machine_profile.R` (cores and the container CPU quota, *available* memory, thread defaults per package, BLAS, OpenMP builds, shared memory (`/dev/shm` on Linux), disk, download tools).

**b. Profile what exists, read-only.**
- `tar_profile.R store=_targets n=20 script=_targets.R measure=<big_target>`: slowest and largest targets, branch statistics, big objects with many downstream targets, estimated hidden save/load time; `measure=` times one real `tar_read()` to calibrate.
- `tar_dag.R overhead=<s>` (default worker counts derive from the machine's cores; `workers=1,2,4` to choose) (per-task overhead from `diagnose.md`): critical path, width, maximum useful speedup, predicted wall time per worker count (`outdated=TRUE` for what would rebuild now).
- `startup_cost.R`: what each new worker pays for R, `.Rprofile` and packages.
- If one target dominates and its inside is unclear: `profile_pipeline.R out=<dir outside project> top=10`, then `profile_summary.R <dir>/profiles`. **This runs pipeline code on a copy of the store: ask first.**

How to read the output: `references/diagnose.md`.

**c. Predict.** Before any build, benchmark or structural change, state expected wall time, peak memory and gain (formulas in `diagnose.md`). Afterwards compare and explain the gap; a gap usually reveals a hidden cost.

**d. Classify the bottleneck**: code inside a few targets, save/load, per-target overhead, missing or excessive parallelism, memory, remote I/O, start-up, BLAS.

**e. Classify and pick strategies** from the table below (`diagnose.md` explains the script output it starts from). Read only the references you need.

**f. Benchmark on subsets.** `tar_read()` real inputs, subset, `bench::mark()`; report ratios; check `identical(old, new)` on the full input before adopting. Use the `r-performance` skill for profvis and bench if available.

**g. Regression check.** `tar_snapshot.R save <dir> store=_targets <names>` before; after the approved rebuild, `tar_snapshot.R compare <dir>` (exit 1 on any difference in data; environments inside models and closures are ignored). Trace differences to rows.

**h. Propose, ranked by gain × exactness × risk.** For each: target(s), file:line, measured speedup on a subset, predicted pipeline gain, whether output stays identical (or why a tolerance is acceptable), what could break. The user picks.

**i. Implement** the chosen changes one at a time, re-check identity, and record each change, its check and its result in the project's decisions log (e.g. `docs/decisions.md`).

## Ask before changing parallel structure

Parallel advice depends on where the pipeline runs. Ask, in one batch:
- Where does it run: laptop, CI runner, shared server, container or cluster? Several of these?
- How many cores and how much memory may it use, and is the machine shared?
- Is there a worker-count convention (e.g. an `NPROC` environment variable), and should the default stay serial?
- Are some hosts rate-limited (one worker each)?

Then size workers × threads ≤ allowed cores and workers × peak per worker ≤ available memory (`parallelism.md`, `memory.md`).

## Symptom → strategy → reference

| Symptom (from step b) | Strategies | Reference |
|---|---|---|
| A few targets dominate; profile shows grouped stats, sort, unique, table, joins | collapse/data.table/kit/Rfast swaps; precomputed groupings | `fast-functions.md` |
| `lapply`/`map`/`apply`/`mapply`/`do.call(rbind)`/`Reduce` in profiles (R-level loops) | vectorized equivalents, one bind, row functions | `vectorization.md` |
| Long text, many regexes or terms; `gsub`/`grepl`/`stri_*` in profiles | fixed prefilter, compute on unique values, lowercase once, charclass, compute once and share | `vectorization.md`, `case-study.md` |
| Filters, joins, aggregates on big tables; big intermediate targets | filter/select early, aggregate before join, distinct first, filter upstream | `query-order.md` |
| Hidden I/O large (wall ≫ sum of target seconds); big `rds` targets; consumers need few columns | `format = "qs"`, qs2 threads, parquet partial reads, `retrieval = "none"`, file targets | `storage-formats.md` |
| Many tiny branches; wall ≫ work | batch (`tar_rep`, `tar_group_count`), fewer bigger branches, `deployment = "main"` | `branching.md` |
| Adding/removing branches at all | weigh organization and incremental caching first | `branching.md` |
| Idle cores; wide DAG; speedup bound well above 1 | crew sized by env var; threads in a single bottleneck target | `parallelism.md` |
| Parallel run slower than predicted | oversubscription, thread env vars, start-up, dispatch floor | `parallelism.md` |
| Killed / swapping / OOM; big object × many workers | memory budget, retrieval settings, partial reads, fewer workers for heavy targets | `memory.md` |
| Big read-only object read by many parallel targets | mori shared formats, or consumers in main | `sharing-mori.md` |
| Remote parquet or many downloads | projection, partitions, sorted row groups, duckdb caches, one connection per process, download vs range read, parallel downloads, per-host controllers | `remote-data.md` |
| `%*%`, `solve`, `lm.fit`, `La_*` in profiles; every worker slow to start; container limits | BLAS (OpenBLAS or MKL threads on Linux and Windows, Accelerate on macOS), OpenMP builds, `.Rprofile`/renv, package placement, upgrades | `environment.md` |
| Where a number came from; your machine vs the test machines | machines, versions, full tables | `benchmarks.md` |

Every reference opens with when it matters and ends with traps. Numbers in them are generated from the benchmark results; quote them as "in the skill's benchmarks", never as guarantees. They come from GitHub Actions runners on Linux, macOS and Windows (x64 and arm64, several BLAS libraries) plus a few local machines; where platforms disagree, `benchmarks.md` says so; tell the user which platform a number came from when theirs differs. Result files cited as `<topic>/<file>.csv` are in the skill's source repository under `bench/`, not in the installed skill; `benchmarks.md` reproduces every row.

## Guardrails

- **Never run `tar_make()` without approval** in a pipeline that has deploy, upload or other side-effect targets (e.g. `*_deployed`, writes outside the store). Build named targets after checking `tar_outdated(names = )`. Profiling and benchmarking use `tar_read()` and copies.
- `profile_pipeline.R` and any rebuild run pipeline code: ask first.
- Never delete or `tar_destroy()` a store, never `tar_prune()` without asking; stores can hold snapshots that cannot be recreated.
- Ask before installing or upgrading packages (including duckdb ≥ 2.0), switching BLAS, upgrading R, or changing lock files. These affect other projects and can change numerical results.
- Size by **available** memory, not physical RAM; other processes share the machine. Run one heavy benchmark at a time, on subsets, in a scratch directory outside the project.
- Propose; the user picks. Report every intended output change (e.g. text normalization) separately from pure speedups.
- Keep scratch stores and scripts out of the repo.

## Subagents

Delegate when the work is large; give each subagent only its step's context. Name the tier as well as the model, since names change.

| Step | Tier | Effort |
|---|---|---|
| Run the read-only scripts and collect outputs (a, b) | small, fast model | low |
| Sweep code for patterns from a reference (e.g. `do.call(rbind`, `apply(`, rds formats) | small, fast model | low |
| Mechanical edits the user approved (format switches, namespacing, package moves) | small, fast model | low |
| Benchmark a candidate rewrite on a subset and check identity (f) | current model | medium |
| Classify, predict, rank and propose (c, d, h); review identity arguments | current model | default |

A profiling subagent's brief: read-only, never `tar_make()`, timings from `tar_meta()` and the scripts, benchmarks on `tar_read()` subsets in a scratch directory, return findings with file:line, measured speedup and output-identity risk.

## Keeping this skill current

Run the `targets-performance-update` skill after package upgrades: it pulls the cross-platform CI benchmark results, checks NEWS for performance changes, reruns what CI cannot, regenerate `tested-versions.csv`, `format-throughput.csv` and the references, and re-verify sources. `check_versions.R` tells you when that is due. Fix the skill at its source repository, not in an installed copy.
