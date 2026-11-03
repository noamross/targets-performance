# AGENTS.md: targets-performance

Source for the `targets-performance` agent skill (speeding up R {targets} pipelines) and its `targets-performance-update` sub-skill, built from web research and benchmarks. Platform-neutral: the skill, the update procedure and the benchmark suite must not assume an OS, CPU, core count, R installer or container runtime. Cross-platform evidence comes from the CI matrix; local runs (a 12-core macOS arm64 machine, an arm64 Linux container) are kept as informational rows.

## Read first, by task

| Task | Read |
|---|---|
| Change the skill | `skills/targets-performance/SKILL.md`, `docs/decisions.md`; edit references in `bench/report/*.qmd`, never the rendered `.md` |
| Refresh benchmarks and references | `skills/targets-performance-update/SKILL.md` |
| CI benchmarks (workflow, suite, importing results) | `.github/workflows/benchmarks.yml`, `bench/suite.csv`, `docs/architecture.md` |
| Rerun or add a benchmark | `bench/<topic>/`, `bench/suite.csv`, `docs/architecture.md` |
| Check a claim's source | `data/sources/facts_*.csv`, `values_*.csv` |
| Background: instructions and skills that shaped the skill | `context/README.md` |

## Layout

- `skills/targets-performance/`: the skill (`SKILL.md`, `references/` generated, `scripts/`). `skills/targets-performance-update/`: sub-skill that refreshes it. Repo is a Claude Code plugin + marketplace (`.claude-plugin/`); bump both versions on every skill change and run `claude plugin validate .`.
- `bench/`: benchmark scripts per topic; results in `bench/<topic>/results/`. Packages: `bench/rproj.toml` (`Rscript bench/deps.R` lists missing ones; rig users can `rig proj sync`).
- `bench/suite.csv` + `bench/run_suite.R`: script manifest (memory cap, `ci` flag, `needs`, `min_cores`, `min_ram_gb`) and the cross-platform capped runner. `bench/run_capped.R <script> [cap_gb]` runs one script.
- `.github/workflows/benchmarks.yml`: reruns the CI rows on an OS/arch/BLAS/R-version matrix when versions change; stores results on the `bench-results` branch. `bench/ci_results.R` imports them to `bench/ci-results/`. `bench/news_since.R`: NEWS since tested versions. Tests: `bench/tests/`.
- `bench/report/`: one Quarto source per reference (`<name>.qmd`, `_helpers.R`, `_quarto.yml`), rendered to gfm in `skills/targets-performance/references/`. Numbers come only from results CSVs (`pick()`) or `data/sources/values_*.csv` (`val()`, `fn()`); claims from `facts_*.csv` (`ffn()`).
- `bench/docker/`: optional Linux container runs with CPU/memory limits.
- `bench/refresh_outputs.R`: regenerates tested-versions, format-throughput and references, then runs the CSV and private-name checks.
- `data/sources/`: per-topic facts and values CSVs with source URLs.
- `context/`: snapshots of instructions, skills and example code that shaped the skill (`context/README.md`). `notes/` (gitignored): the maintainer's local logs.

## How to run

```sh
cd bench && Rscript run_suite.R topics=storage   # or: Rscript run_capped.R <topic>/<script>.R [cap_gb]
Rscript bench/refresh_outputs.R                  # from the repo root; needs Quarto and knitr + rmarkdown
```

## Conventions

- Platform-neutral code: plain `Rscript` (rig optional), `processx`/`ps` rather than shell tools, `.Platform$path.sep`, core counts from `bench_cores()` and memory from `mem_budget_mb()`. Scripts skip what the machine can't run (logged) instead of failing.
- Benchmarks: ratios over absolutes; check `identical()` on every rewrite; record machine, cores, R and package versions, date in results. One benchmark at a time, always under a memory cap (`run_suite.R`/`run_capped.R`). Keep any single object ≤ 400 MB. Scratch stores and big files go in `BENCH_SCRATCH` (default: a temp dir), never the repo.
- References render with the default R on PATH; `_helpers.R` uses base R only.
- Never `tar_make()` in a real project. Remote benchmarks: public no-key endpoints only; no writes anywhere.
- Before every commit, run `Rscript bench/refresh_outputs.R`; it greps `skills/` for patterns in the local gitignored `.private-names` file (if present).

## Standing approvals

- 2026-11-03: local commits in this repo.
- 2026-11-03: create a public repo under github.com/noamross for this project, push to it, and dispatch the `benchmarks` workflow to test CI.
- 2026-11-02: install zap, Rfast2, fastverse, kit, fst in the benchmark library.

## Package notes

- zap (coolbutuseless/zap 0d4101d, 0.1.1.9002) fails to build on R 4.6.2 (`Rf_findVar` removed from the R API). A local patched build can go in `bench/.extralib/` (gitignored), which `_common.R` adds to the library path. Storage scripts skip zap and fst when they are missing or fail to load.

## Don't

- Don't commit anything that names the maintainer's other projects, or code copied from them. Exceptions agreed for `context/`: duckspending example code. Other private material stays in `notes/` (gitignored).
- Don't commit files over 50 MB (GitHub rejects > 100 MB); keep large outputs gitignored and commit a summary CSV.
