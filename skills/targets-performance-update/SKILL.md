---
name: targets-performance-update
description: "Refresh the targets-performance skill from its source repository: pull the cross-platform CI benchmark results (Linux, macOS, Windows; x64 and arm64; several BLAS libraries and R versions), scan R, package and system-library NEWS and the web for performance changes since the tested versions, rerun on the current machine only what CI flags or cannot run, regenerate tested package versions, format throughput and the generated reference pages, re-verify the cited sources, bump the plugin and marketplace versions and validate. Works on any OS. Use when check_versions.R reports newer or older packages, after a major package release (targets, crew, qs2, duckdb, data.table, collapse), when CI flags changes, or when a reference looks stale. Keywords: targets-performance, benchmarks, CI, GitHub Actions, bench-results, NEWS, rerun, tested-versions, format-throughput, quarto render, references, sources, plugin version, claude plugin validate."
argument-hint: "[topics to rerun locally, e.g. 'storage targets_mech' or 'none'] [--dispatch-ci]"
---

# targets-performance-update

Refresh the skill's evidence and regenerate everything derived from it. One job: refresh. Changing advice is proposed to the user, not done silently.

## Environment

- Needs a local agent with a shell, R (any installer; `Rscript` on PATH), Quarto, git, and a clone of the skill's source repository. Optional: `gh` (CI dispatch, tool release lists), a container runtime (Linux runs with CPU/memory limits). Works on Linux, macOS and Windows; don't assume the machine's OS, cores or memory: read them from `machine_profile.R`.
- claude.ai cannot run this; it can only review results someone pastes.

## Before starting

1. Open the source repository and read `AGENTS.md` (conventions, standing approvals) and `docs/architecture.md` (what makes each file).
2. Ask the user which topics, if any, to rerun on this machine, and whether it may install or upgrade packages (`Rscript bench/deps.R` lists missing ones; `install=TRUE` installs them). Never upgrade in passing.
3. Run `Rscript skills/targets-performance/scripts/machine_profile.R` and keep the output with the date.

## 1. Pull CI results

The `benchmarks` GitHub Actions workflow reruns the suite rows with `ci == TRUE` (`bench/suite.csv`) on a matrix of OSs, CPU architectures, BLAS libraries and R versions whenever R or package versions change, and stores results on the `bench-results` branch. This is the main evidence; it doesn't depend on where you run.

```sh
cd bench && Rscript ci_results.R
```

It copies the latest run per runner into `bench/ci-results/<label>/` (the cross-platform section of `benchmarks.md` reads it) and writes `bench/ci-results/flags.csv`: scripts that failed or were skipped in CI, medians that moved more than 25% since the previous run, and tasks whose fastest method changed, each with the reference page it feeds.

If the stored run is older than the latest package releases, ask the user before dispatching a fresh run (`gh workflow run benchmarks -f force=true`; it takes hours and uses CI minutes).

## 2. Check NEWS and recent developments

```sh
cd bench && Rscript news_since.R        # pkgs=targets,qs2  all=TRUE  r=FALSE  tools=FALSE
```

It reads `tested-versions.csv` and lists NEWS items newer than the tested versions for R (r-source `NEWS.Rd`, including R-devel and patched) and each tested package (`NEWS.md` from CRAN's GitHub mirror), flagging items that mention speed, memory, threads, caching, serialization and similar. With `gh` it also lists releases since the tested date for related system libraries (OpenBLAS, duckdb, Arrow, zstd, curl). The flags are broad: read every flagged item and keep those that change what a pipeline author should do.

Then search the web for developments since the tested date that NEWS files miss: new packages or tools for fast R, `{targets}`/`crew` performance features, duckdb and Arrow R features, BLAS and OpenMP changes on each OS, and posts on the Posit, tidyverse, R Consortium, duckdb, data.table and rOpenSci blogs. Prefer primary sources (NEWS, release notes, docs, the author's post).

For each finding that matters:

- Record it in `data/sources/facts_<topic>.csv` (claims) or `values_<topic>.csv` (numbers) with the exact URL, retrieval date and a short verbatim quote.
- If it needs evidence, add or extend a benchmark script and its `bench/suite.csv` row (`ci` TRUE when it runs on GitHub runners; set `needs`, `min_cores`, `min_ram_gb`), so the next CI run measures it on every platform.
- Propose the advice change to the user.

## 3. Rerun on this machine (only what's needed)

Rerun the topics the user chose, CI flags you want to confirm, and rows CI can't run (`ci == FALSE`, `needs` docker or blas-switch). From `bench/`, one script at a time, each under a memory cap that also covers detached workers:

```sh
Rscript run_suite.R topics=storage              # or scripts=a.R,b.R; ci=TRUE for the CI set
Rscript run_capped.R <topic>/<script>.R [cap_gb]
```

- The runner skips rows the machine can't meet (`min_cores`, `min_ram_gb`, `needs`) and logs why. Results carry `machine` (set `BENCH_ENV_LABEL` to a descriptive label), `cores`, `r_version`, `run_date`.
- Several scripts replace rows with the same topic/task/n/method key, whatever the machine. Before rerunning on a machine other than the one that made the committed rows, move the topic's results aside or write to a copy, so local rows don't overwrite the reference rows the `.qmd` files pick.
- Switching BLAS or OpenMP builds changes the whole R installation: ask first, and restore afterwards.
- Optional Linux container runs: `bench/docker/` (Dockerfile; `run.sh <mem> <cpus> <shm> <cmd>`).

## 4. Regenerate

```sh
Rscript bench/refresh_outputs.R
```

It writes `tested-versions.csv` and `format-throughput.csv`, renders every reference (`quarto render bench/report`), checks the source CSVs for malformed rows and greps `skills/` for patterns in the local `.private-names` file if present. A render error usually means a result row changed name or count: fix the `.qmd`, not the rendered `.md`.

Read the reference diffs (`git diff skills/targets-performance/references`) and the CI cross-platform table. Where a ratio crossed a decision threshold, or the fastest method differs by platform, propose the text change (state which platforms it holds on).

## 5. Re-verify sources

Spot-check `data/sources/facts_*.csv` and `values_*.csv` URLs (at least those whose package had a release since `retrieved`), update `retrieved` and the quote, and add an archive link for pages likely to change. Flag what you couldn't re-verify; don't delete without asking.

## 6. Release

1. Bump the version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (same number); run `claude plugin validate .`.
2. Record what changed (CI run used, topics rerun locally and on which machine, notable shifts) in `docs/decisions.md`.
3. Commit only with the user's approval or a standing approval in `AGENTS.md`; never push without asking.

## Subagents

| Step | Tier | Effort |
|---|---|---|
| Run one benchmark script and report exit status, peak memory and rows written | small, fast model | low |
| Triage flagged NEWS items (a few packages per subagent) | small, fast model | low |
| Spot-check source URLs and quotes | small, fast model | low |
| Web search for recent developments; decide which findings change advice | current model | default |
| Fix a `.qmd` after a result rename; read diffs and CI flags, propose advice changes | current model | default |

Run benchmark subagents one after another, never in parallel.

## Keeping this skill current

When the benchmark layout changes (new topic, renamed script, new results file), update this skill, `bench/suite.csv`, the topic map in `bench/ci_results.R`, `bench/refresh_outputs.R` and `docs/architecture.md` in the same change. Edit this skill in its source repository, not an installed copy.
