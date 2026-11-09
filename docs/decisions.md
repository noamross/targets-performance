# Decisions

| Date | Decision | Status | Where / by |
|---|---|---|---|
| 2026-11-02 | Skill source in this repo; user moves it later | agreed | user, session 1 |
| 2026-11-02 | Benchmark deps in a rig project under `bench/` | superseded (2026-11-03 platform-neutral row) | user ("use rig") |
| 2026-11-02 | Add remote parquet / duckdb / duckplyr topic | agreed | user |
| 2026-11-02 | zap patched locally for R 4.6 API, in `bench/.extralib/`, outside rig manifest | agreed (benchmarks only) | session 1, see AGENTS.md |
| 2026-11-03 | License MIT | agreed | user |
| 2026-11-03 | duckdb >= 2.0 is a recommended upgrade (with user approval) | agreed | user |
| 2026-11-03 | References are Quarto sources in `bench/report/` rendered to gfm in `skills/targets-performance/references/`; no hand-typed benchmark numbers (pick()/val()/fn()/ffn() helpers); SKILL.md carries no numbers | proposed | integration brief |
| 2026-11-03 | Bench files named after the case-study project renamed (`vectorize/b6_text_tricks*.R`, `results/b6_text_tricks.csv`) so skill references stay repo-neutral | proposed | integration agent |
| 2026-11-03 | Case-study numbers transcribed into `data/sources/values_case.csv` (source: unpublished case notes from the pipeline author) | proposed | integration agent |
| 2026-11-03 | Plugin and marketplace version 0.2.0 (skill written; update sub-skill added) | proposed | integration agent |
| 2026-11-03 | Review fixes (review and fix logs kept locally, unpublished): `retrieval = "auto"` is the default and references say what it does; c1/c2/c4/c6/c6b/c7/c8 rows labelled `retrieval = "worker"`; result files cited as `<topic>/<file>.csv` in the source repository; `tar_snapshot.R compare` ignores environments (data still exact); symptom table only in SKILL.md; smart quotes off in `_quarto.yml` | proposed | fixes agent |
| 2026-11-03 | Benchmark facts only in run logs (duckdb spill in a 2 GB container) transcribed to `bench/docker/results/b7_duckdb_spill.csv` so references read them from a results CSV | proposed | fixes agent |
| 2026-11-03 | Rename skill, plugin and repo dir to targets-performance; update sub-skill to targets-performance-update | agreed | user |
| 2026-11-03 | CI benchmarks (`.github/workflows/benchmarks.yml`): weekly + manual; reruns `suite.csv` rows with `ci == TRUE` only when R or package versions changed since the stored run (or `force`). Matrix: Linux x64 (release, devel), Linux arm64, macOS arm64 (reference and Accelerate BLAS), macOS x64, Windows x64, rocker/r-ver x64 (OpenBLAS and reference). Results stored on an orphan `bench-results` branch, pulled by `bench/ci_results.R` | proposed | main agent (user request: CI job) |
| 2026-11-03 | CI installs packages with `r-lib/actions/setup-r-dependencies` (latest CRAN/P3M binaries), not rig; zap (needs a patched build) and fst (fails to load on macOS) excluded; storage scripts skip methods whose package is missing | proposed | main agent |
| 2026-11-03 | CI clears committed `bench/*/results/` before running, since `write_result()` keys rows without the machine and would mix local rows into the artifact | proposed | main agent |
| 2026-11-03 | `run_suite.R` limits each script to `timeout_min` (default 30) besides the memory cap; `suite.csv` `est_min` left blank until the first CI run log gives times | proposed | main agent |
| 2026-11-03 | Platform-neutral skill, update skill and suite: plain `Rscript` (rig optional; `rproj.toml` stays the package list, `bench/deps.R` lists missing ones), R helpers replace bash (`run_capped.R`, `refresh_outputs.R`), worker/thread counts and object sizes derive from `bench_cores()` and `mem_budget_mb()`, `suite.csv` gains `min_cores`/`min_ram_gb` and the runner skips (status -1) what a machine can't run. CI matrix is the main cross-platform evidence; the local macOS 12-core and arm64-container rows stay as informational data | agreed | user |
| 2026-11-03 | Public repo github.com/noamross/targets-performance with fresh history; `notes/` gitignored and kept local; `context/` published except example code from two other projects (kept in `notes/`) (user, 2026-11-03); project-name patterns for the skills/ check live in gitignored `.private-names` | agreed | user |
| 2026-11-03 | BLAS output `.rds` files (153 MB each) gitignored; `blas.R` writes cross-BLAS differences to `blas/results/blas_diffs.csv`, which `environment.qmd` reads | proposed | main agent |
| 2026-11-03 | `bench/ci-results/` committed when imported, so the shipped `benchmarks.md` renders the cross-platform table reproducibly | proposed | main agent |
| 2026-11-09 | `run_suite.R` caps each script at min(suite.csv `cap_gb` or `cap_gb=` override, 60% of total RAM), not of free memory: macOS counts reclaimable cache as used, so 7 GB macOS runners capped scripts at 2 GB and killed them (run 42574321334). CI no longer passes `cap_gb=4`, so suite.csv caps apply | agreed | user |
| 2026-11-09 | CI matrix sharded by topic (3 shards: `targets_mech`; `vectorize,remote,blas`; `fastfns,storage,startup`) via `run_suite.R topics=`; whole topics per shard because scripts in one topic share result CSVs. Artifacts `bench-<label>-s<k>`; `store` merges shards into one `<label>/` and concatenates run logs; a shard with no selected scripts exits 0 | agreed | user (plan) |
| 2026-11-09 | rocker containers run with `--shm-size=4g` (Docker default 64 MB `/dev/shm` breaks mori) | agreed | user (plan) |
| 2026-11-09 | Results site `bench/site/` (Quarto website, ggplot2): status grid, suite time per run, ratio heatmaps per topic, `ci_results.R` flags, versions; built by the `site` job from the bench-results branch and pushed to `gh-pages` | agreed | user |

## Open questions

| Raised | Question | Options | Evidence | Owner |
|---|---|---|---|---|
| 2026-11-09 | R-devel job builds arrow from source (50 min) and failed on a github.com 504 while CMake fetched Boost | rerun; cache libarrow; `continue-on-error` for devel | run 42574321334 job 129019077728 | user |
| 2026-11-09 | ggplot2 is a site-only dependency (references stay base R) | keep; base graphics | `bench/site/` | user |
