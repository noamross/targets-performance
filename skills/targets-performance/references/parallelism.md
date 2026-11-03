# Parallelism: workers, branches and threads


**When this matters.** The build is slow and the machine has idle cores, or a parallel build is slower or uses more memory than expected. Parallel R work happens at three levels: **pipeline workers** (crew runs independent targets at once), **branches** (dynamic or static branches give workers more independent pieces), and **threads inside a target** (data.table, collapse, BLAS, duckdb, arrow, qs2, Stan). Speed comes from using the right level, and from never stacking them so that workers × threads exceeds the cores.

## Before changing anything

Ask the user where the pipeline runs (laptop, CI runner, shared server, container), how many cores and how much free memory it may use, and whether others share the machine. Then run:

- `machine_profile.R`: cores, *available* memory, container CPU/memory limits, thread defaults per package, BLAS.
- `tar_dag.R workers=1,2,4,8`: maximum useful speedup (total seconds / critical path) and predicted wall time per worker count. If the speedup bound is 1.5x, eight workers cannot help; shorten the critical path instead.

## Pipeline workers (crew)

With 24 independent 2-second targets, wall time fell from 50 s (serial) to 27 s, 15 s and 11 s with 2, 4 and 6 workers. Each worker is a separate R process: peak memory grew from 337 MB to 1.6 GB. Source: benchmark results `targets_mech/c1_nproc.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`).

Workers have fixed costs: start-up (seconds) and a round trip per target. 200 targets of 20 ms took 5.2 s serially; one crew worker took 7.1 s, and six workers still needed 3.2 s because the main process dispatches targets one at a time. Tiny targets do not parallelize; batch them (`branching.md`) or run them in the main process with `deployment = "main"`.

A portable pattern: size the controller from an environment variable, serial by default, so laptops, CI and servers each choose their worker count.

``` r
# _targets.R
nproc <- as.integer(Sys.getenv("NPROC", "1"))
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", R_DATATABLE_NUM_THREADS = "1")  # before workers start
tar_option_set(
  controller = if (nproc > 1) crew::crew_controller_local(workers = nproc, seconds_idle = 60),
  deployment = if (nproc > 1) "worker" else "main"
)
```

Rate-limited hosts get their own one-worker controller in a `crew_controller_group()`, and their fetch targets set `resources = tar_resources(crew = tar_resources_crew(controller = "<host>"))` (see `remote-data.md`).

## Threads inside a target

One multithreaded target can match many single-threaded branches with far less memory. Six data.table jobs:

| setup                                    | wall  | peak memory |
|:-----------------------------------------|:------|:------------|
| 1 target, 6 jobs in sequence, 6 threads  | 4.7 s | 792 MB      |
| 1 target, 1 thread                       | 9.1 s | 783 MB      |
| 6 branches x 1 thread (NPROC = 6)        | 5.0 s | 3.3 GB      |
| 6 branches x 2 threads (12 threads)      | 4.9 s | 3.3 GB      |
| 6 branches x 6 threads (36 on 12 cores)  | 6.2 s | 3.4 GB      |
| 6 branches x 12 threads (72 on 12 cores) | 11 s  | 3.4 GB      |

Source: benchmark results `targets_mech/c8_level.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`). First of two repetitions shown.

So a one-off heavy step (a big sort, join or grouped summary in a single bottleneck target) is often better served by threads in that one target than by splitting it into branches: no worker start-up, no extra copies, and the same wall time when the work is memory-bandwidth-bound. Split into branches when the pieces are independent and CPU-bound, when each piece is long enough to amortize overhead, or for the organization and caching benefits in `branching.md`.

Model fitting follows the same rule. A package that runs MCMC chains in parallel inside one call (cmdstanr `parallel_chains`, brms `cores`) uses threads well for one or a few fits; split chains or fits into branches only when many cores are idle, compilation is cached, and seeds are set per branch. Keep chains × threads per chain × workers ≤ cores.

## Oversubscription

When workers × threads per worker exceeds the cores, threads fight for CPU and every target slows down:

- 6 mirai workers each running data.table: 1.5 s with 1 thread each, 2.1 s with data.table's default (half the CPUs each), 9.5 s with all CPUs each. Source: benchmark results `startup/oversubscribe.csv` (run 2026-11-03).
- 3 workers doing BLAS work in a 6-CPU Linux container (OpenBLAS pthreads): 2.0 s with 2 threads each, 2.9 s with 1, 8.1 s with 6, and 40 s with the default (all host CPUs, ignoring the container limit). Source: benchmark results `blas/blas_workers_linux.csv` (Linux aarch64, 12 cores, R 4.6.2; run 2026-11-03).

Defaults that oversubscribe under parallel workers: data.table (half the logical CPUs), OpenBLAS and OpenMP (all CPUs), arrow (all CPUs), duckdb (all CPUs, and 80% of RAM as `memory_limit` per process). collapse, kit, qs2 and Rfast default to 1 thread. Inside containers, data.table, BLAS and arrow count host CPUs, not the container's quota; duckdb follows the quota.

## Getting thread settings into workers

Environment variables set in `_targets.R` **before** workers start are inherited by crew and mirai workers:

| engine | set before start          | data.table threads in worker |
|:-------|:--------------------------|-----------------------------:|
| mirai  | none set                  |                            6 |
| crew   | none set                  |                            6 |
| mirai  | R_DATATABLE_NUM_THREADS=1 |                            1 |
| crew   | R_DATATABLE_NUM_THREADS=1 |                            1 |
| mirai  | OMP_NUM_THREADS=1         |                            1 |
| crew   | OMP_NUM_THREADS=1         |                            1 |
| mirai  | both = 1                  |                            1 |
| crew   | both = 1                  |                            1 |

Source: benchmark results `fastfns/b6_envworkers.csv` (run 2026-11-03). A variable set after a worker was already running did not reach it (worker saw <unset>).

- `R_DATATABLE_NUM_THREADS` set in `_targets.R` does **not** affect the main process (targets has already loaded data.table) or serial runs. Call `data.table::setDTthreads(n)` inside the function as well.
- OpenBLAS: the pthread build obeys `OPENBLAS_NUM_THREADS` and falls back to `OMP_NUM_THREADS`; the OpenMP build obeys only `OMP_NUM_THREADS`. Set both. At run time, `RhpcBLASctl::blas_set_num_threads()` works for the pthread build and `omp_set_num_threads()` for the OpenMP build; calling the wrong one does nothing (3 workers: 22 s with the wrong setter vs 2.9 s with the right one).
- duckdb: set `threads` and `memory_limit` per connection (`duckdb::duckdb(config = list(threads = "2", memory_limit = "2GB"))`).
- qs2: `tar_resources_qs(nthreads = 1)` inside workers. arrow: `arrow::set_cpu_count(n)`.

A budget: threads per worker = cores available / workers, memory per worker ≤ available memory / (workers + 1).

## Worker start-up

Every crew worker is a fresh `Rscript` that runs the project `.Rprofile` and loads the packages in `tar_option_set(packages = )`. With the default long-lived workers this is paid once per worker: six heavy packages loaded globally cost about the same wall time as loading them only in the two targets that use them (3.6 s vs 3.5 s). With `tasks_max = 1` (a fresh worker per target) the same pipeline took 9.3 s and 6.7 s. Source: benchmark results `targets_mech/c2_startup.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`).

So:

- Keep workers alive (`tasks_max = Inf`, `seconds_idle` of a minute or more); recycle only to contain memory leaks.
- Attach in `tar_option_set(packages = )` only packages most targets use. Give a heavy package used by a few targets to those targets' `packages =` argument, or call it as `pkg::fn()`.
- Keep `.Rprofile` cheap; see `environment.md` (renv activation and checks added 470 ms per worker start in the benchmarks).
- `startup_cost.R` measures R, `.Rprofile` and per-package load times for your project.

## Traps

- **Nested parallel frameworks.** `mirai::daemons(n)` inside a target that already runs on a mirai/crew worker fails; `purrr::in_parallel()` or `furrr` inside workers multiplies processes. Pick one level.
- **Forking after OpenMP.** With the OpenMP build of OpenBLAS, `parallel::mclapply()` children hung when they called BLAS after the parent had used BLAS or data.table threads. crew, mirai and callr start fresh processes and are not affected.
- **Detached workers escape monitoring.** crew and mirai workers are not children of the R session in the process tree (their launcher exits and they lose the parent link; on macOS they reparent to `launchd`). Measure pipeline memory with system available memory or by summing all R processes, not the session's own RSS.
- **`detectCores()` lies in containers** (reports host CPUs). Read the cgroup quota; `machine_profile.R` prints it, and `parallelly::availableCores()` respects it.
- More workers than the DAG's width only add memory and start-up.
