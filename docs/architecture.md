# Architecture

| Path | Made by | From |
|---|---|---|
| `bench/<topic>/results/*.csv` | `bench/<topic>/*.R` via `bench/run_suite.R` or `run_capped.R` | synthetic data, package versions in rows |
| `bench/*/results/*_linux.csv` | `bench/docker/*.R`, `*.sh` via `bench/docker/run.sh` | Linux container (`bench/docker/Dockerfile`) |
| `bench/docker/results/b7_duckdb_spill.csv` | transcribed by hand from the `bench/docker/b7_mem_duckdb.R` run log | Linux container, `--memory=2g` |
| `skills/targets-performance/references/<name>.md` | `quarto render bench/report` (`bench/report/<name>.qmd`, `_helpers.R`) | `bench/*/results/*.csv`, `data/sources/values_*.csv`, `facts_*.csv`, `skills/targets-performance/tested-versions.csv`, `format-throughput.csv`, `bench/ci-results/` |
| `data/sources/facts_*.csv`, `values_*.csv` | research agents; `values_case.csv` transcribed from unpublished case notes | web sources, local help pages, unpublished case notes |
| `skills/targets-performance/tested-versions.csv` | `bench/write_tested_versions.R` | installed bench library |
| `skills/targets-performance/format-throughput.csv` | `bench/storage/write_throughput.R` | `bench/storage/results/storage.csv` |
| all three generated outputs above | `bench/refresh_outputs.R` (one command) | as above |
| `bench/ci/run_log.csv`, `bench/ci/logs/*.log` (gitignored) | `bench/run_suite.R` | scripts listed in `bench/suite.csv` |
| `bench-results` branch: `runs/<date>-<HHMMSS>-<sha7>/<label>/`, `latest/<label>/`, `latest/versions.csv`, `index.csv` | `.github/workflows/benchmarks.yml` (`store` job) | per-runner artifacts `bench-<label>-s<shard>` (merged per label; run logs concatenated): `bench/*/results/`, `bench/ci/` (run log, `session_info.txt`, `machine_profile.txt`, `versions.csv`); `latest/versions.csv` from the `check-updates` job's `versions` artifact, stored only when a runner wrote a run log |
| NEWS report `news-since-<date>.md` (bench scratch dir, not in repo) | `bench/news_since.R` | `skills/targets-performance/tested-versions.csv`; r-source `doc/NEWS.Rd`, CRAN GitHub mirror `NEWS.md`, `gh release list` |
| `bench/ci-results/<label>/`, `bench/ci-results/flags.csv` | `bench/ci_results.R` | `bench-results` branch (`latest/`, previous run via `index.csv`) |
| `bench/blas/results/blas.csv`, `blas_diffs.csv` (`blas_<variant>.rds` gitignored) | `bench/blas/blas.R`, once per BLAS variant | R's linked BLAS |
| `gh-pages` branch (results site); `bench/site/_site/`, `bench/site/figures/` locally (gitignored) | `quarto render bench/site` (`index.qmd`, `topics.qmd`, `_data.R`); `site` job in `.github/workflows/benchmarks.yml` pushes it | `bench-results` branch checkout (`BENCH_RESULTS`), `flags.csv` from `bench/ci_results.R` (`CI_FLAGS`) |
