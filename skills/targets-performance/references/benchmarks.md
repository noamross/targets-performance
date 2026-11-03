# Benchmarks: machines, versions and full results


**When this matters.** To check where a number in another reference came from, to compare your machine with the test machines, or to rerun a benchmark. This file is long; search it rather than reading it whole. Every other reference cites the CSV each number comes from, as `<topic>/<file>.csv`.

**Where the results are.** The result CSVs, benchmark scripts and run logs are not shipped with the skill. They live in the skill's source repository (see its `README.md`) under `bench/<topic>/results/`; the tables below reproduce every row.

## Machines

| machine       | cores | R     |
|:--------------|------:|:------|
| Darwin arm64  |    12 | 4.6.2 |
| Linux aarch64 |    12 | 4.6.2 |
| Linux aarch64 |    NA | 4.6.2 |

Two local machines contributed most of the rows the other references quote; they are informational, not the platforms the skill assumes. Cross-platform evidence is in the next section.

- **macOS (local):** Apple Silicon (arm64), with R's reference BLAS except where the BLAS benchmark switched to Accelerate. Other work ran on the machine at the same time; numbers are medians and should be read as ratios.
- **Linux (local container):** an ARM64 container (`rocker/r-ver` image, Ubuntu, in a Linux VM on the same Mac), run with explicit `--memory`, `--cpus` and `--shm-size` limits. The `cores` column is what the VM reports; the container's CPU quota was lower for the thread and BLAS runs. Not x86.
- Remote benchmarks used a home internet connection; seconds there are single runs, bytes exact.

## Package versions

Versions of the benchmark library (source repository `bench/rproj.toml`, lock file `bench/rproj.lock`), as recorded in `tested-versions.csv` (tested 2026-11-03 on R 4.6.2, aarch64-apple-darwin23):

| package     | version    | package    | version  |
|:------------|:-----------|:-----------|:---------|
| targets     | 1.12.0     | data.table | 1.18.6.1 |
| tarchetypes | 0.14.1     | kit        | 0.0.21   |
| crew        | 1.3.3      | Rfast      | 2.1.5.2  |
| mirai       | 2.7.3      | Rfast2     | 0.1.5.6  |
| qs2         | 0.3.1      | fastverse  | 0.3.4    |
| mori        | 0.2.2      | fst        | 0.9.8    |
| zap         | 0.1.1.9002 | stringi    | 1.8.9    |
| nanoparquet | 0.5.2      | vctrs      | 0.7.3    |
| arrow       | 26.0.0     | purrr      | 1.2.2    |
| duckdb      | 2.0.0      | dplyr      | 1.2.1    |
| duckplyr    | 1.2.2      | curl       | 8.1.0    |
| dbplyr      | 2.6.0      | httr2      | 1.3.0    |
| collapse    | 2.1.8      | bench      | 1.1.4    |

The Linux container used P3M binaries of the same CRAN versions, except where its rows' `packages` column says otherwise (e.g. qs2 and mirai patch releases).

## Cross-platform runs (CI)

No CI results imported yet. The source repository's `benchmarks` GitHub Actions workflow reruns the CI-safe scripts (`bench/suite.csv`) on several OSs, CPU architectures, BLAS libraries and R versions; `bench/ci_results.R` imports them into `bench/ci-results/`.

## How to rerun

In the source repository, from `bench/`, on any OS, one script at a time under a memory cap (the runner skips scripts the machine can't meet):

``` sh
Rscript run_suite.R topics=storage   # or: Rscript run_capped.R <topic>/<script>.R [cap_gb]
```

Optional Linux container runs with CPU and memory limits: `bench/docker/`. Afterwards run `Rscript bench/refresh_outputs.R` from the repository root (tested versions, format throughput, these references). The `targets-performance-update` skill lists the full procedure.

## Full results

<details>

<summary>

Source: benchmark results `blas/blas_diffs.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 8 rows
</summary>

| task             | n   | method     |
|:-----------------|:----|:-----------|
| crossprod        | NA  | accelerate |
| matmul           | NA  | accelerate |
| solve            | NA  | accelerate |
| chol             | NA  | accelerate |
| svd_1000         | NA  | accelerate |
| qr               | NA  | accelerate |
| lm_fit_2e5x51    | NA  | accelerate |
| glm_logit_2e5x51 | NA  | accelerate |

</details>

<details>

<summary>

Source: benchmark results `blas/blas_dt_linux.csv` (Linux aarch64, 12 cores, R 4.6.2; run 2026-11-03) 32 rows
</summary>

| task                    |    n | method              | median_s |
|:------------------------|-----:|:--------------------|---------:|
| dt_alone                | 1500 | pthread\|OB=6,OMP=6 |    0.073 |
| blas_alone              | 1500 | pthread\|OB=6,OMP=6 |    0.021 |
| dt_plus_blas_sequential | 1500 | pthread\|OB=6,OMP=6 |    0.119 |
| fork_children_blas_s    | 1500 | pthread\|OB=6,OMP=6 |    0.030 |
| dt_alone                | 1500 | pthread\|OB=1,OMP=6 |    0.058 |
| blas_alone              | 1500 | pthread\|OB=1,OMP=6 |    0.061 |
| dt_plus_blas_sequential | 1500 | pthread\|OB=1,OMP=6 |    0.119 |
| fork_children_blas_s    | 1500 | pthread\|OB=1,OMP=6 |    0.065 |
| dt_alone                | 1500 | pthread\|OB=-,OMP=6 |    0.058 |
| blas_alone              | 1500 | pthread\|OB=-,OMP=6 |    0.015 |
| dt_plus_blas_sequential | 1500 | pthread\|OB=-,OMP=6 |    0.121 |
| fork_children_blas_s    | 1500 | pthread\|OB=-,OMP=6 |    0.030 |
| dt_alone                | 1500 | pthread\|OB=-,OMP=- |    0.058 |
| blas_alone              | 1500 | pthread\|OB=-,OMP=- |    0.021 |
| dt_plus_blas_sequential | 1500 | pthread\|OB=-,OMP=- |    0.163 |
| fork_children_blas_s    | 1500 | pthread\|OB=-,OMP=- |    0.040 |
| dt_alone                | 1500 | openmp\|OB=6,OMP=6  |    0.058 |
| blas_alone              | 1500 | openmp\|OB=6,OMP=6  |    0.014 |
| dt_plus_blas_sequential | 1500 | openmp\|OB=6,OMP=6  |    0.072 |
| fork_children_blas_s    | 1500 | openmp\|OB=6,OMP=6  |       NA |
| dt_alone                | 1500 | openmp\|OB=1,OMP=6  |    0.058 |
| blas_alone              | 1500 | openmp\|OB=1,OMP=6  |    0.014 |
| dt_plus_blas_sequential | 1500 | openmp\|OB=1,OMP=6  |    0.072 |
| fork_children_blas_s    | 1500 | openmp\|OB=1,OMP=6  |       NA |
| dt_alone                | 1500 | openmp\|OB=-,OMP=6  |    0.058 |
| blas_alone              | 1500 | openmp\|OB=-,OMP=6  |    0.014 |
| dt_plus_blas_sequential | 1500 | openmp\|OB=-,OMP=6  |    0.072 |
| fork_children_blas_s    | 1500 | openmp\|OB=-,OMP=6  |       NA |
| dt_alone                | 1500 | openmp\|OB=-,OMP=-  |    0.058 |
| blas_alone              | 1500 | openmp\|OB=-,OMP=-  |    0.020 |
| dt_plus_blas_sequential | 1500 | openmp\|OB=-,OMP=-  |    0.080 |
| fork_children_blas_s    | 1500 | openmp\|OB=-,OMP=-  |       NA |

</details>

<details>

<summary>

Source: benchmark results `blas/blas_linux.csv` (Linux aarch64, 12 cores, R 4.6.2; run 2026-11-03) 128 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|:---|:---|
| crossprod | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 3.83000 | NA | NA |
| matmul | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 2.18300 | NA | NA |
| solve | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 2.50200 | NA | NA |
| chol | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 1.21000 | NA | NA |
| svd_1000 | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 1.85800 | NA | NA |
| qr | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 3.05300 | NA | NA |
| lm_fit_2e5x51 | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.37430 | NA | NA |
| glm_logit_2e5x51 | 2000 | reference\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 3.84300 | NA | NA |
| crossprod | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.14540 | NA | NA |
| matmul | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.28210 | NA | NA |
| solve | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.42120 | NA | NA |
| chol | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.05508 | NA | NA |
| svd_1000 | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.32860 | NA | NA |
| qr | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.91340 | NA | NA |
| lm_fit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.15310 | NA | NA |
| glm_logit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 1.73300 | NA | NA |
| crossprod | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.14690 | NA | NA |
| matmul | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.28180 | NA | NA |
| solve | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.42060 | NA | NA |
| chol | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.05504 | NA | NA |
| svd_1000 | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.32950 | NA | NA |
| qr | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.91870 | NA | NA |
| lm_fit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.15290 | NA | NA |
| glm_logit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 1.73300 | NA | NA |
| crossprod | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.14530 | NA | NA |
| matmul | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.28380 | NA | NA |
| solve | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.42260 | NA | NA |
| chol | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.05496 | NA | NA |
| svd_1000 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.32790 | NA | NA |
| qr | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.92200 | NA | NA |
| lm_fit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.15280 | NA | NA |
| glm_logit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 1.73900 | NA | NA |
| crossprod | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.14580 | NA | NA |
| matmul | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.28170 | NA | NA |
| solve | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.42220 | NA | NA |
| chol | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.05504 | NA | NA |
| svd_1000 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.32820 | NA | NA |
| qr | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.91500 | NA | NA |
| lm_fit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.15260 | NA | NA |
| glm_logit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 1.73000 | NA | NA |
| crossprod | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.14530 | NA | NA |
| matmul | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.28240 | NA | NA |
| solve | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.42070 | NA | NA |
| chol | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.05508 | NA | NA |
| svd_1000 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.32740 | NA | NA |
| qr | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.91820 | NA | NA |
| lm_fit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.15250 | NA | NA |
| glm_logit_2e5x51 | 2000 | serial\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 1.73800 | NA | NA |
| crossprod | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.14490 | NA | NA |
| matmul | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.28080 | NA | NA |
| solve | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.42400 | NA | NA |
| chol | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.05519 | NA | NA |
| svd_1000 | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.32670 | NA | NA |
| qr | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.91790 | NA | NA |
| lm_fit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.15430 | NA | NA |
| glm_logit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 1.71000 | NA | NA |
| crossprod | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.03041 | NA | NA |
| matmul | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.05398 | NA | NA |
| solve | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.09136 | NA | NA |
| chol | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.01348 | NA | NA |
| svd_1000 | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.18540 | NA | NA |
| qr | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.92300 | NA | NA |
| lm_fit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.08877 | NA | NA |
| glm_logit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 1.13500 | NA | NA |
| crossprod | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.14600 | NA | NA |
| matmul | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.28190 | NA | NA |
| solve | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.42160 | NA | NA |
| chol | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.05503 | NA | NA |
| svd_1000 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.32850 | NA | NA |
| qr | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.93010 | NA | NA |
| lm_fit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.15700 | NA | NA |
| glm_logit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 1.69600 | NA | NA |
| crossprod | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.03044 | NA | NA |
| matmul | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.05478 | NA | NA |
| solve | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.09126 | NA | NA |
| chol | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.01349 | NA | NA |
| svd_1000 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.18520 | NA | NA |
| qr | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.92430 | NA | NA |
| lm_fit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.08863 | NA | NA |
| glm_logit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 1.13500 | NA | NA |
| crossprod | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.09141 | NA | NA |
| matmul | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.16680 | NA | NA |
| solve | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 1.42000 | NA | NA |
| chol | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.03875 | NA | NA |
| svd_1000 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.55590 | NA | NA |
| qr | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.92290 | NA | NA |
| lm_fit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.20560 | NA | NA |
| glm_logit_2e5x51 | 2000 | pthread\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 1.96700 | NA | NA |
| crossprod | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.08508 | NA | NA |
| matmul | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.11310 | NA | NA |
| solve | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.15420 | NA | NA |
| chol | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.07627 | NA | NA |
| svd_1000 | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.48660 | NA | NA |
| qr | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.92430 | NA | NA |
| lm_fit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 0.87390 | NA | NA |
| glm_logit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=1,OMP_NUM_THREADS=- | 8.02600 | NA | NA |
| crossprod | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.09105 | NA | NA |
| matmul | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.11580 | NA | NA |
| solve | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.18390 | NA | NA |
| chol | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.09275 | NA | NA |
| svd_1000 | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.49230 | NA | NA |
| qr | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.92110 | NA | NA |
| lm_fit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 0.82360 | NA | NA |
| glm_logit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=6,OMP_NUM_THREADS=- | 7.99400 | NA | NA |
| crossprod | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.14490 | NA | NA |
| matmul | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.28120 | NA | NA |
| solve | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.42110 | NA | NA |
| chol | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.05535 | NA | NA |
| svd_1000 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.32640 | NA | NA |
| qr | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.92610 | NA | NA |
| lm_fit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 0.15320 | NA | NA |
| glm_logit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=1 | 1.69500 | NA | NA |
| crossprod | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.03040 | NA | NA |
| matmul | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.05399 | NA | NA |
| solve | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.09307 | NA | NA |
| chol | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.01371 | NA | NA |
| svd_1000 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.21920 | NA | NA |
| qr | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.92360 | NA | NA |
| lm_fit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 0.08833 | NA | NA |
| glm_logit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=6 | 1.16000 | NA | NA |
| crossprod | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.07769 | NA | NA |
| matmul | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.11820 | NA | NA |
| solve | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.13210 | NA | NA |
| chol | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.08461 | NA | NA |
| svd_1000 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.46390 | NA | NA |
| qr | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.91940 | NA | NA |
| lm_fit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 0.87670 | NA | NA |
| glm_logit_2e5x51 | 2000 | openmp\|OPENBLAS_NUM_THREADS=-,OMP_NUM_THREADS=- | 8.06500 | NA | NA |

</details>

<details>

<summary>

Source: benchmark results `blas/blas_workers_linux.csv` (Linux aarch64, 12 cores, R 4.6.2; run 2026-11-03) 17 rows
</summary>

| task        |   n | method              | median_s |
|:------------|----:|:--------------------|---------:|
| W1_rt_none  |   6 | pthread\|OB=6,OMP=- |    3.053 |
| W3_rt_none  |   6 | pthread\|OB=6,OMP=- |    8.075 |
| W3_rt_none  |   6 | pthread\|OB=1,OMP=- |    2.947 |
| W3_rt_none  |   6 | pthread\|OB=2,OMP=- |    2.022 |
| W3_rt_none  |   6 | pthread\|OB=-,OMP=- |   40.300 |
| W3_rt_blas1 |   6 | pthread\|OB=-,OMP=- |    2.948 |
| W3_rt_blas2 |   6 | pthread\|OB=-,OMP=- |    1.981 |
| W3_rt_omp1  |   6 | pthread\|OB=-,OMP=- |   31.280 |
| W1_rt_none  |   6 | openmp\|OB=-,OMP=6  |    3.103 |
| W3_rt_none  |   6 | openmp\|OB=-,OMP=6  |    7.564 |
| W3_rt_none  |   6 | openmp\|OB=-,OMP=1  |    2.944 |
| W3_rt_none  |   6 | openmp\|OB=-,OMP=2  |    1.970 |
| W3_rt_none  |   6 | openmp\|OB=-,OMP=-  |   22.020 |
| W3_rt_blas1 |   6 | openmp\|OB=-,OMP=-  |   22.400 |
| W3_rt_omp1  |   6 | openmp\|OB=-,OMP=-  |    2.947 |
| W3_rt_omp2  |   6 | openmp\|OB=-,OMP=-  |    1.984 |
| W3_rt_both2 |   6 | openmp\|OB=-,OMP=-  |    1.983 |

</details>

<details>

<summary>

Source: benchmark results `blas/blas.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 16 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|:---|:---|
| crossprod | 2000 | libRblas.0.dylib | 4.11600 | NA | NA |
| matmul | 2000 | libRblas.0.dylib | 2.18700 | NA | NA |
| solve | 2000 | libRblas.0.dylib | 2.48800 | NA | NA |
| chol | 2000 | libRblas.0.dylib | 1.25100 | NA | NA |
| svd_1000 | 2000 | libRblas.0.dylib | 1.85800 | NA | NA |
| qr | 2000 | libRblas.0.dylib | 3.14700 | NA | NA |
| lm_fit_2e5x51 | 2000 | libRblas.0.dylib | 0.38080 | NA | NA |
| glm_logit_2e5x51 | 2000 | libRblas.0.dylib | 3.73000 | NA | NA |
| crossprod | 2000 | accelerate | 0.02338 | NA | NA |
| matmul | 2000 | accelerate | 0.04512 | NA | NA |
| solve | 2000 | accelerate | 0.14040 | NA | NA |
| chol | 2000 | accelerate | 0.01351 | NA | NA |
| svd_1000 | 2000 | accelerate | 0.13580 | NA | NA |
| qr | 2000 | accelerate | 2.04900 | NA | NA |
| lm_fit_2e5x51 | 2000 | accelerate | 0.15230 | NA | NA |
| glm_logit_2e5x51 | 2000 | accelerate | 1.66000 | NA | NA |

</details>

<details>

<summary>

Source: benchmark results `docker/b7_duckdb_spill.csv` (Linux aarch64, R 4.6.2; run 2026-11-03) 4 rows
</summary>

| task | method |
|:---|:---|
| ORDER BY hash(i) over 1.5e8 rows (about 2.4 GB sort, spills) | default memory_limit |
| ORDER BY hash(i) over 1.5e8 rows (about 2.4 GB sort, spills) | SET threads=2 |
| ORDER BY hash(i) over 1.5e8 rows (about 2.4 GB sort, spills) | memory_limit = '1GB' |
| ORDER BY hash(i) over 1.5e8 rows (about 2.4 GB sort, spills) | memory_limit = '12GB' |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b1_grouped.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 265 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| grouped_sum_int_few | 1e+03 | base_rowsum | 2.420e-05 | 4.108 | TRUE |
| grouped_sum_int_few | 1e+03 | base_tapply | 5.990e-05 | 10.150 | TRUE |
| grouped_sum_int_few | 1e+03 | base_aggregate | 3.704e-04 | 62.740 | TRUE |
| grouped_sum_int_few | 1e+03 | dplyr | 8.158e-04 | 138.200 | TRUE |
| grouped_sum_int_few | 1e+03 | DT | 2.655e-04 | 44.960 | TRUE |
| grouped_sum_int_few | 1e+03 | collapse | 9.700e-06 | 1.642 | TRUE |
| grouped_sum_int_few | 1e+03 | collapse_GRP | 5.900e-06 | 1.000 | TRUE |
| grouped_sum_int_few | 1e+03 | collapse_nosort | 4.300e-05 | 7.285 | TRUE |
| grouped_sum_int_few | 1e+03 | Rfast_group | 7.600e-06 | 1.285 | TRUE |
| grouped_mean_int_few | 1e+03 | base_tapply | 1.371e-04 | 18.370 | TRUE |
| grouped_mean_int_few | 1e+03 | dplyr | 5.208e-04 | 69.790 | TRUE |
| grouped_mean_int_few | 1e+03 | DT | 2.737e-04 | 36.680 | FALSE |
| grouped_mean_int_few | 1e+03 | collapse | 2.080e-05 | 2.791 | FALSE |
| grouped_mean_int_few | 1e+03 | collapse_GRP | 1.280e-05 | 1.712 | FALSE |
| grouped_mean_int_few | 1e+03 | Rfast_group | 7.500e-06 | 1.000 | FALSE |
| grouped_median_int_few | 1e+03 | base_tapply | 1.553e-04 | 19.530 | TRUE |
| grouped_median_int_few | 1e+03 | dplyr | 5.886e-04 | 74.000 | TRUE |
| grouped_median_int_few | 1e+03 | DT | 2.332e-04 | 29.320 | TRUE |
| grouped_median_int_few | 1e+03 | collapse | 2.370e-05 | 2.985 | TRUE |
| grouped_median_int_few | 1e+03 | collapse_GRP | 8.000e-06 | 1.000 | TRUE |
| grouped_median_int_few | 1e+03 | Rfast_group | 1.010e-05 | 1.271 | TRUE |
| grouped_quantile90_int_few | 1e+03 | base_tapply | 8.866e-04 | 118.200 | TRUE |
| grouped_quantile90_int_few | 1e+03 | dplyr | 1.049e-03 | 139.900 | TRUE |
| grouped_quantile90_int_few | 1e+03 | DT | 1.237e-03 | 164.900 | TRUE |
| grouped_quantile90_int_few | 1e+03 | collapse_fnth | 1.830e-05 | 2.437 | FALSE |
| grouped_quantile90_int_few | 1e+03 | collapse_fnth_GRP | 7.500e-06 | 1.000 | FALSE |
| grouped_sum_chr_few | 1e+03 | base_rowsum | 2.530e-05 | 1.919 | TRUE |
| grouped_sum_chr_few | 1e+03 | base_tapply | 1.053e-04 | 7.989 | TRUE |
| grouped_sum_chr_few | 1e+03 | base_aggregate | 2.948e-03 | 223.700 | TRUE |
| grouped_sum_chr_few | 1e+03 | dplyr | 1.285e-03 | 97.460 | TRUE |
| grouped_sum_chr_few | 1e+03 | DT | 5.114e-04 | 38.800 | TRUE |
| grouped_sum_chr_few | 1e+03 | collapse | 3.030e-05 | 2.295 | TRUE |
| grouped_sum_chr_few | 1e+03 | collapse_GRP | 1.320e-05 | 1.000 | TRUE |
| grouped_sum_chr_few | 1e+03 | collapse_nosort | 5.870e-05 | 4.456 | TRUE |
| grouped_mean_chr_few | 1e+03 | base_tapply | 1.143e-04 | 18.470 | TRUE |
| grouped_mean_chr_few | 1e+03 | dplyr | 9.663e-04 | 156.100 | TRUE |
| grouped_mean_chr_few | 1e+03 | DT | 6.094e-04 | 98.430 | FALSE |
| grouped_mean_chr_few | 1e+03 | collapse | 1.150e-05 | 1.858 | FALSE |
| grouped_mean_chr_few | 1e+03 | collapse_GRP | 6.200e-06 | 1.000 | FALSE |
| grouped_median_chr_few | 1e+03 | base_tapply | 3.847e-04 | 42.370 | TRUE |
| grouped_median_chr_few | 1e+03 | dplyr | 1.323e-03 | 145.700 | TRUE |
| grouped_median_chr_few | 1e+03 | DT | 6.813e-04 | 75.020 | TRUE |
| grouped_median_chr_few | 1e+03 | collapse | 5.380e-05 | 5.923 | TRUE |
| grouped_median_chr_few | 1e+03 | collapse_GRP | 9.100e-06 | 1.000 | TRUE |
| grouped_quantile90_chr_few | 1e+03 | base_tapply | 5.178e-04 | 51.760 | TRUE |
| grouped_quantile90_chr_few | 1e+03 | dplyr | 1.164e-03 | 116.300 | TRUE |
| grouped_quantile90_chr_few | 1e+03 | DT | 9.735e-04 | 97.320 | TRUE |
| grouped_quantile90_chr_few | 1e+03 | collapse_fnth | 2.270e-05 | 2.270 | FALSE |
| grouped_quantile90_chr_few | 1e+03 | collapse_fnth_GRP | 1.000e-05 | 1.000 | FALSE |
| grouped_sum_int_many | 1e+03 | base_rowsum | 2.450e-05 | 4.061 | TRUE |
| grouped_sum_int_many | 1e+03 | base_tapply | 1.314e-04 | 21.810 | TRUE |
| grouped_sum_int_many | 1e+03 | base_aggregate | 6.708e-04 | 111.300 | TRUE |
| grouped_sum_int_many | 1e+03 | dplyr | 8.102e-04 | 134.400 | TRUE |
| grouped_sum_int_many | 1e+03 | DT | 2.921e-04 | 48.460 | TRUE |
| grouped_sum_int_many | 1e+03 | collapse | 1.170e-05 | 1.942 | TRUE |
| grouped_sum_int_many | 1e+03 | collapse_GRP | 6.000e-06 | 1.000 | TRUE |
| grouped_sum_int_many | 1e+03 | collapse_nosort | 5.680e-05 | 9.425 | TRUE |
| grouped_sum_int_many | 1e+03 | Rfast_group | 7.700e-06 | 1.282 | TRUE |
| grouped_mean_int_many | 1e+03 | base_tapply | 2.179e-04 | 35.910 | TRUE |
| grouped_mean_int_many | 1e+03 | dplyr | 1.367e-03 | 225.300 | TRUE |
| grouped_mean_int_many | 1e+03 | DT | 3.347e-04 | 55.150 | FALSE |
| grouped_mean_int_many | 1e+03 | collapse | 9.600e-06 | 1.578 | FALSE |
| grouped_mean_int_many | 1e+03 | collapse_GRP | 6.100e-06 | 1.000 | FALSE |
| grouped_mean_int_many | 1e+03 | Rfast_group | 2.270e-05 | 3.736 | FALSE |
| grouped_median_int_many | 1e+03 | base_tapply | 1.189e-03 | 143.600 | TRUE |
| grouped_median_int_many | 1e+03 | dplyr | 3.439e-03 | 415.300 | TRUE |
| grouped_median_int_many | 1e+03 | DT | 4.198e-04 | 50.690 | FALSE |
| grouped_median_int_many | 1e+03 | collapse | 2.030e-05 | 2.450 | FALSE |
| grouped_median_int_many | 1e+03 | collapse_GRP | 8.300e-06 | 1.000 | FALSE |
| grouped_median_int_many | 1e+03 | Rfast_group | 2.610e-05 | 3.146 | FALSE |
| grouped_quantile90_int_many | 1e+03 | base_tapply | 6.778e-03 | 847.800 | TRUE |
| grouped_quantile90_int_many | 1e+03 | dplyr | 7.474e-03 | 934.800 | TRUE |
| grouped_quantile90_int_many | 1e+03 | DT | 7.446e-03 | 931.300 | TRUE |
| grouped_quantile90_int_many | 1e+03 | collapse_fnth | 4.460e-05 | 5.572 | FALSE |
| grouped_quantile90_int_many | 1e+03 | collapse_fnth_GRP | 8.000e-06 | 1.000 | FALSE |
| grouped_sum_chr_many | 1e+03 | base_rowsum | 1.226e-04 | 21.350 | TRUE |
| grouped_sum_chr_many | 1e+03 | base_tapply | 1.949e-04 | 33.950 | TRUE |
| grouped_sum_chr_many | 1e+03 | base_aggregate | 1.248e-03 | 217.500 | TRUE |
| grouped_sum_chr_many | 1e+03 | dplyr | 1.002e-03 | 174.600 | TRUE |
| grouped_sum_chr_many | 1e+03 | DT | 4.530e-04 | 78.910 | TRUE |
| grouped_sum_chr_many | 1e+03 | collapse | 1.970e-05 | 3.432 | TRUE |
| grouped_sum_chr_many | 1e+03 | collapse_GRP | 5.700e-06 | 1.000 | TRUE |
| grouped_sum_chr_many | 1e+03 | collapse_nosort | 1.446e-04 | 25.190 | TRUE |
| grouped_mean_chr_many | 1e+03 | base_tapply | 3.142e-04 | 52.680 | TRUE |
| grouped_mean_chr_many | 1e+03 | dplyr | 1.156e-03 | 193.700 | TRUE |
| grouped_mean_chr_many | 1e+03 | DT | 5.141e-04 | 86.180 | FALSE |
| grouped_mean_chr_many | 1e+03 | collapse | 1.900e-05 | 3.189 | FALSE |
| grouped_mean_chr_many | 1e+03 | collapse_GRP | 6.000e-06 | 1.000 | FALSE |
| grouped_median_chr_many | 1e+03 | base_tapply | 1.903e-03 | 221.500 | TRUE |
| grouped_median_chr_many | 1e+03 | dplyr | 3.250e-03 | 378.400 | TRUE |
| grouped_median_chr_many | 1e+03 | DT | 8.308e-04 | 96.720 | FALSE |
| grouped_median_chr_many | 1e+03 | collapse | 3.200e-05 | 3.721 | FALSE |
| grouped_median_chr_many | 1e+03 | collapse_GRP | 8.600e-06 | 1.000 | FALSE |
| grouped_quantile90_chr_many | 1e+03 | base_tapply | 7.089e-03 | 1011.000 | TRUE |
| grouped_quantile90_chr_many | 1e+03 | dplyr | 9.461e-03 | 1349.000 | TRUE |
| grouped_quantile90_chr_many | 1e+03 | DT | 5.563e-03 | 793.500 | TRUE |
| grouped_quantile90_chr_many | 1e+03 | collapse_fnth | 2.450e-05 | 3.488 | FALSE |
| grouped_quantile90_chr_many | 1e+03 | collapse_fnth_GRP | 7.000e-06 | 1.000 | FALSE |
| grouped_sum_int_few | 1e+05 | base_rowsum | 1.032e-03 | 12.260 | TRUE |
| grouped_sum_int_few | 1e+05 | base_tapply | 2.179e-03 | 25.880 | TRUE |
| grouped_sum_int_few | 1e+05 | base_aggregate | 2.014e-02 | 239.200 | TRUE |
| grouped_sum_int_few | 1e+05 | dplyr | 1.083e-03 | 12.870 | TRUE |
| grouped_sum_int_few | 1e+05 | DT | 1.779e-03 | 21.130 | TRUE |
| grouped_sum_int_few | 1e+05 | collapse | 1.746e-04 | 2.074 | TRUE |
| grouped_sum_int_few | 1e+05 | collapse_GRP | 8.420e-05 | 1.000 | TRUE |
| grouped_sum_int_few | 1e+05 | collapse_nosort | 2.247e-04 | 2.669 | TRUE |
| grouped_sum_int_few | 1e+05 | Rfast_group | 1.657e-04 | 1.968 | TRUE |
| grouped_mean_int_few | 1e+05 | base_tapply | 2.084e-03 | 24.430 | TRUE |
| grouped_mean_int_few | 1e+05 | dplyr | 1.084e-03 | 12.710 | TRUE |
| grouped_mean_int_few | 1e+05 | DT | 1.709e-03 | 20.030 | FALSE |
| grouped_mean_int_few | 1e+05 | collapse | 1.808e-04 | 2.119 | FALSE |
| grouped_mean_int_few | 1e+05 | collapse_GRP | 8.530e-05 | 1.000 | FALSE |
| grouped_mean_int_few | 1e+05 | Rfast_group | 3.944e-04 | 4.622 | FALSE |
| grouped_median_int_few | 1e+05 | base_tapply | 2.998e-03 | 3.146 | TRUE |
| grouped_median_int_few | 1e+05 | dplyr | 2.707e-03 | 2.841 | TRUE |
| grouped_median_int_few | 1e+05 | DT | 2.797e-03 | 2.935 | TRUE |
| grouped_median_int_few | 1e+05 | collapse | 1.231e-03 | 1.292 | TRUE |
| grouped_median_int_few | 1e+05 | collapse_GRP | 9.530e-04 | 1.000 | TRUE |
| grouped_median_int_few | 1e+05 | Rfast_group | 1.214e-03 | 1.274 | TRUE |
| grouped_quantile90_int_few | 1e+05 | base_tapply | 3.418e-03 | 5.712 | TRUE |
| grouped_quantile90_int_few | 1e+05 | dplyr | 3.008e-03 | 5.027 | TRUE |
| grouped_quantile90_int_few | 1e+05 | DT | 2.109e-03 | 3.525 | TRUE |
| grouped_quantile90_int_few | 1e+05 | collapse_fnth | 9.743e-04 | 1.628 | FALSE |
| grouped_quantile90_int_few | 1e+05 | collapse_fnth_GRP | 5.983e-04 | 1.000 | FALSE |
| grouped_sum_chr_few | 1e+05 | base_rowsum | 1.029e-03 | 12.220 | TRUE |
| grouped_sum_chr_few | 1e+05 | base_tapply | 2.587e-03 | 30.700 | TRUE |
| grouped_sum_chr_few | 1e+05 | base_aggregate | 2.100e-02 | 249.200 | TRUE |
| grouped_sum_chr_few | 1e+05 | dplyr | 1.218e-03 | 14.460 | TRUE |
| grouped_sum_chr_few | 1e+05 | DT | 2.115e-03 | 25.110 | TRUE |
| grouped_sum_chr_few | 1e+05 | collapse | 1.927e-04 | 2.287 | TRUE |
| grouped_sum_chr_few | 1e+05 | collapse_GRP | 8.420e-05 | 1.000 | TRUE |
| grouped_sum_chr_few | 1e+05 | collapse_nosort | 2.262e-04 | 2.684 | TRUE |
| grouped_mean_chr_few | 1e+05 | base_tapply | 2.656e-03 | 31.280 | TRUE |
| grouped_mean_chr_few | 1e+05 | dplyr | 1.270e-03 | 14.950 | TRUE |
| grouped_mean_chr_few | 1e+05 | DT | 1.879e-03 | 22.120 | FALSE |
| grouped_mean_chr_few | 1e+05 | collapse | 1.876e-04 | 2.209 | FALSE |
| grouped_mean_chr_few | 1e+05 | collapse_GRP | 8.490e-05 | 1.000 | FALSE |
| grouped_median_chr_few | 1e+05 | base_tapply | 3.609e-03 | 4.155 | TRUE |
| grouped_median_chr_few | 1e+05 | dplyr | 3.059e-03 | 3.522 | TRUE |
| grouped_median_chr_few | 1e+05 | DT | 2.739e-03 | 3.153 | TRUE |
| grouped_median_chr_few | 1e+05 | collapse | 1.085e-03 | 1.249 | TRUE |
| grouped_median_chr_few | 1e+05 | collapse_GRP | 8.686e-04 | 1.000 | TRUE |
| grouped_quantile90_chr_few | 1e+05 | base_tapply | 4.572e-03 | 6.843 | TRUE |
| grouped_quantile90_chr_few | 1e+05 | dplyr | 2.916e-03 | 4.364 | TRUE |
| grouped_quantile90_chr_few | 1e+05 | DT | 2.277e-03 | 3.407 | TRUE |
| grouped_quantile90_chr_few | 1e+05 | collapse_fnth | 9.183e-04 | 1.374 | FALSE |
| grouped_quantile90_chr_few | 1e+05 | collapse_fnth_GRP | 6.681e-04 | 1.000 | FALSE |
| grouped_sum_int_many | 1e+05 | base_rowsum | 4.107e-03 | 68.890 | TRUE |
| grouped_sum_int_many | 1e+05 | base_tapply | 9.816e-03 | 164.700 | TRUE |
| grouped_sum_int_many | 1e+05 | base_aggregate | 6.787e-02 | 1139.000 | TRUE |
| grouped_sum_int_many | 1e+05 | dplyr | 1.850e-02 | 310.300 | TRUE |
| grouped_sum_int_many | 1e+05 | DT | 1.974e-03 | 33.110 | TRUE |
| grouped_sum_int_many | 1e+05 | collapse | 3.659e-04 | 6.138 | TRUE |
| grouped_sum_int_many | 1e+05 | collapse_GRP | 5.960e-05 | 1.000 | TRUE |
| grouped_sum_int_many | 1e+05 | collapse_nosort | 4.578e-04 | 7.680 | TRUE |
| grouped_sum_int_many | 1e+05 | Rfast_group | 1.736e-03 | 29.120 | FALSE |
| grouped_mean_int_many | 1e+05 | base_tapply | 3.542e-02 | 249.500 | TRUE |
| grouped_mean_int_many | 1e+05 | dplyr | 5.062e-02 | 356.500 | TRUE |
| grouped_mean_int_many | 1e+05 | DT | 3.668e-03 | 25.830 | FALSE |
| grouped_mean_int_many | 1e+05 | collapse | 1.845e-03 | 12.990 | FALSE |
| grouped_mean_int_many | 1e+05 | collapse_GRP | 1.420e-04 | 1.000 | FALSE |
| grouped_mean_int_many | 1e+05 | Rfast_group | 8.757e-03 | 61.680 | FALSE |
| grouped_median_int_many | 1e+05 | base_tapply | 2.196e-01 | 176.300 | TRUE |
| grouped_median_int_many | 1e+05 | dplyr | 2.506e-01 | 201.300 | TRUE |
| grouped_median_int_many | 1e+05 | DT | 8.484e-03 | 6.813 | FALSE |
| grouped_median_int_many | 1e+05 | collapse | 2.388e-03 | 1.918 | FALSE |
| grouped_median_int_many | 1e+05 | collapse_GRP | 1.245e-03 | 1.000 | FALSE |
| grouped_median_int_many | 1e+05 | Rfast_group | 1.147e-02 | 9.214 | FALSE |
| grouped_quantile90_int_many | 1e+05 | base_tapply | 6.627e-01 | 538.100 | TRUE |
| grouped_quantile90_int_many | 1e+05 | dplyr | 9.397e-01 | 763.000 | TRUE |
| grouped_quantile90_int_many | 1e+05 | DT | 1.278e+00 | 1038.000 | TRUE |
| grouped_quantile90_int_many | 1e+05 | collapse_fnth | 1.385e-03 | 1.125 | FALSE |
| grouped_quantile90_int_many | 1e+05 | collapse_fnth_GRP | 1.232e-03 | 1.000 | FALSE |
| grouped_sum_chr_many | 1e+05 | base_rowsum | 4.102e-02 | 712.700 | TRUE |
| grouped_sum_chr_many | 1e+05 | base_tapply | 3.656e-02 | 635.100 | TRUE |
| grouped_sum_chr_many | 1e+05 | base_aggregate | 1.268e-01 | 2203.000 | TRUE |
| grouped_sum_chr_many | 1e+05 | dplyr | 2.365e-02 | 410.800 | TRUE |
| grouped_sum_chr_many | 1e+05 | DT | 2.601e-03 | 45.190 | TRUE |
| grouped_sum_chr_many | 1e+05 | collapse | 1.167e-03 | 20.270 | TRUE |
| grouped_sum_chr_many | 1e+05 | collapse_GRP | 5.760e-05 | 1.000 | TRUE |
| grouped_sum_chr_many | 1e+05 | collapse_nosort | 1.127e-03 | 19.570 | TRUE |
| grouped_mean_chr_many | 1e+05 | base_tapply | 5.362e-02 | 537.300 | TRUE |
| grouped_mean_chr_many | 1e+05 | dplyr | 5.766e-02 | 577.800 | TRUE |
| grouped_mean_chr_many | 1e+05 | DT | 2.784e-03 | 27.900 | FALSE |
| grouped_mean_chr_many | 1e+05 | collapse | 1.201e-03 | 12.030 | FALSE |
| grouped_mean_chr_many | 1e+05 | collapse_GRP | 9.980e-05 | 1.000 | FALSE |
| grouped_median_chr_many | 1e+05 | base_tapply | 1.980e-01 | 210.800 | TRUE |
| grouped_median_chr_many | 1e+05 | dplyr | 1.760e-01 | 187.400 | TRUE |
| grouped_median_chr_many | 1e+05 | DT | 4.040e-03 | 4.301 | FALSE |
| grouped_median_chr_many | 1e+05 | collapse | 2.462e-03 | 2.622 | FALSE |
| grouped_median_chr_many | 1e+05 | collapse_GRP | 9.392e-04 | 1.000 | FALSE |
| grouped_quantile90_chr_many | 1e+05 | base_tapply | 8.133e-01 | 865.500 | TRUE |
| grouped_quantile90_chr_many | 1e+05 | dplyr | 8.666e-01 | 922.200 | TRUE |
| grouped_quantile90_chr_many | 1e+05 | DT | 7.042e-01 | 749.400 | TRUE |
| grouped_quantile90_chr_many | 1e+05 | collapse_fnth | 2.188e-03 | 2.329 | FALSE |
| grouped_quantile90_chr_many | 1e+05 | collapse_fnth_GRP | 9.397e-04 | 1.000 | FALSE |
| grouped_sum_chr_few | 1e+07 | base_rowsum | 1.502e-01 | 10.060 | TRUE |
| grouped_sum_chr_few | 1e+07 | base_tapply | 2.855e-01 | 19.120 | TRUE |
| grouped_sum_chr_few | 1e+07 | base_aggregate | 8.806e+00 | 589.700 | TRUE |
| grouped_sum_chr_few | 1e+07 | dplyr | 1.368e+00 | 91.590 | TRUE |
| grouped_sum_chr_few | 1e+07 | DT | 1.523e+00 | 102.000 | TRUE |
| grouped_sum_chr_few | 1e+07 | collapse | 2.468e-01 | 16.530 | TRUE |
| grouped_sum_chr_few | 1e+07 | collapse_GRP | 1.493e-02 | 1.000 | TRUE |
| grouped_sum_chr_few | 1e+07 | collapse_nosort | 4.662e-02 | 3.122 | TRUE |
| grouped_mean_chr_few | 1e+07 | base_tapply | 5.641e-01 | 32.450 | TRUE |
| grouped_mean_chr_few | 1e+07 | dplyr | 2.545e+00 | 146.400 | TRUE |
| grouped_mean_chr_few | 1e+07 | DT | 6.846e-01 | 39.380 | FALSE |
| grouped_mean_chr_few | 1e+07 | collapse | 4.826e-01 | 27.760 | FALSE |
| grouped_mean_chr_few | 1e+07 | collapse_GRP | 1.739e-02 | 1.000 | FALSE |
| grouped_median_chr_few | 1e+07 | base_tapply | 9.169e-01 | 3.881 | TRUE |
| grouped_median_chr_few | 1e+07 | dplyr | 5.552e-01 | 2.350 | TRUE |
| grouped_median_chr_few | 1e+07 | DT | 3.946e-01 | 1.670 | TRUE |
| grouped_median_chr_few | 1e+07 | collapse | 2.632e-01 | 1.114 | TRUE |
| grouped_median_chr_few | 1e+07 | collapse_GRP | 2.363e-01 | 1.000 | TRUE |
| grouped_quantile90_chr_few | 1e+07 | base_tapply | 5.840e+00 | 7.235 | TRUE |
| grouped_quantile90_chr_few | 1e+07 | dplyr | 2.035e+00 | 2.521 | TRUE |
| grouped_quantile90_chr_few | 1e+07 | DT | 3.174e+00 | 3.931 | TRUE |
| grouped_quantile90_chr_few | 1e+07 | collapse_fnth | 1.730e+00 | 2.143 | FALSE |
| grouped_quantile90_chr_few | 1e+07 | collapse_fnth_GRP | 8.073e-01 | 1.000 | FALSE |
| grouped_sum_int_few | 1e+07 | base_rowsum | 8.278e-02 | 10.800 | TRUE |
| grouped_sum_int_few | 1e+07 | base_tapply | 1.995e-01 | 26.040 | TRUE |
| grouped_sum_int_few | 1e+07 | base_aggregate | 1.326e+00 | 173.100 | TRUE |
| grouped_sum_int_few | 1e+07 | dplyr | 6.360e-02 | 8.300 | TRUE |
| grouped_sum_int_few | 1e+07 | DT | 1.398e-01 | 18.250 | TRUE |
| grouped_sum_int_few | 1e+07 | collapse | 1.513e-02 | 1.974 | TRUE |
| grouped_sum_int_few | 1e+07 | collapse_GRP | 7.662e-03 | 1.000 | TRUE |
| grouped_sum_int_few | 1e+07 | collapse_nosort | 1.516e-02 | 1.979 | TRUE |
| grouped_sum_int_few | 1e+07 | Rfast_group | 1.620e-02 | 2.114 | TRUE |
| grouped_mean_int_few | 1e+07 | base_tapply | 1.984e-01 | 25.740 | TRUE |
| grouped_mean_int_few | 1e+07 | dplyr | 6.668e-02 | 8.650 | TRUE |
| grouped_mean_int_few | 1e+07 | DT | 1.433e-01 | 18.590 | FALSE |
| grouped_mean_int_few | 1e+07 | collapse | 1.517e-02 | 1.968 | FALSE |
| grouped_mean_int_few | 1e+07 | collapse_GRP | 7.708e-03 | 1.000 | FALSE |
| grouped_mean_int_few | 1e+07 | Rfast_group | 3.827e-02 | 4.964 | FALSE |
| grouped_median_int_few | 1e+07 | base_tapply | 2.740e-01 | 3.346 | TRUE |
| grouped_median_int_few | 1e+07 | dplyr | 1.444e-01 | 1.764 | TRUE |
| grouped_median_int_few | 1e+07 | DT | 2.086e-01 | 2.548 | TRUE |
| grouped_median_int_few | 1e+07 | collapse | 1.069e-01 | 1.305 | TRUE |
| grouped_median_int_few | 1e+07 | collapse_GRP | 8.188e-02 | 1.000 | TRUE |
| grouped_median_int_few | 1e+07 | Rfast_group | 1.022e-01 | 1.248 | TRUE |
| grouped_quantile90_int_few | 1e+07 | base_tapply | 2.625e-01 | 3.917 | TRUE |
| grouped_quantile90_int_few | 1e+07 | dplyr | 1.298e-01 | 1.937 | TRUE |
| grouped_quantile90_int_few | 1e+07 | DT | 1.361e-01 | 2.031 | TRUE |
| grouped_quantile90_int_few | 1e+07 | collapse_fnth | 9.858e-02 | 1.471 | FALSE |
| grouped_quantile90_int_few | 1e+07 | collapse_fnth_GRP | 6.702e-02 | 1.000 | FALSE |
| grouped_sum_int_many | 1e+07 | base_rowsum | 4.025e-01 | 37.440 | TRUE |
| grouped_sum_int_many | 1e+07 | dplyr | 2.255e+00 | 209.700 | TRUE |
| grouped_sum_int_many | 1e+07 | DT | 3.483e-01 | 32.390 | TRUE |
| grouped_sum_int_many | 1e+07 | collapse | 1.000e-01 | 9.304 | TRUE |
| grouped_sum_int_many | 1e+07 | collapse_GRP | 1.075e-02 | 1.000 | TRUE |
| grouped_sum_int_many | 1e+07 | collapse_nosort | 8.383e-02 | 7.797 | TRUE |
| grouped_sum_int_many | 1e+07 | Rfast_group | 2.735e-01 | 25.440 | FALSE |
| grouped_mean_int_many | 1e+07 | base_tapply | 3.467e+00 | 179.200 | TRUE |
| grouped_mean_int_many | 1e+07 | dplyr | 4.657e+00 | 240.800 | TRUE |
| grouped_mean_int_many | 1e+07 | DT | 3.436e-01 | 17.760 | FALSE |
| grouped_mean_int_many | 1e+07 | collapse | 1.109e-01 | 5.731 | FALSE |
| grouped_mean_int_many | 1e+07 | collapse_GRP | 1.934e-02 | 1.000 | FALSE |
| grouped_mean_int_many | 1e+07 | Rfast_group | 1.206e+00 | 62.370 | FALSE |
| grouped_median_int_many | 1e+07 | DT | 6.090e-01 | 3.328 | TRUE |
| grouped_median_int_many | 1e+07 | dplyr | 1.394e+01 | 76.150 | FALSE |
| grouped_median_int_many | 1e+07 | collapse | 2.883e-01 | 1.575 | TRUE |
| grouped_median_int_many | 1e+07 | collapse_GRP | 1.830e-01 | 1.000 | TRUE |
| grouped_median_int_many | 1e+07 | Rfast_group | 1.476e+00 | 8.064 | FALSE |
| grouped_quantile90_int_many | 1e+07 | collapse_fnth | 2.478e-01 | 1.660 | TRUE |
| grouped_quantile90_int_many | 1e+07 | collapse_fnth_GRP | 1.492e-01 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b2_matrix.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 81 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| matrix_rowSums | 1e+03 | base | 0.0000026 | 2.207 | TRUE |
| matrix_rowSums | 1e+03 | Rfast | 0.0000012 | 1.000 | TRUE |
| matrix_rowSums | 1e+03 | collapse_t | 0.0000047 | 3.966 | FALSE |
| matrix_rowSums | 1e+03 | kit_psum | 0.0000151 | 12.690 | TRUE |
| matrix_rowMeans | 1e+03 | base | 0.0000024 | 1.526 | TRUE |
| matrix_rowMeans | 1e+03 | Rfast | 0.0000016 | 1.000 | TRUE |
| matrix_rowMeans | 1e+03 | collapse_t | 0.0000047 | 3.039 | FALSE |
| matrix_colSums | 1e+03 | base | 0.0000021 | 1.962 | TRUE |
| matrix_colSums | 1e+03 | Rfast | 0.0000011 | 1.000 | FALSE |
| matrix_colSums | 1e+03 | collapse | 0.0000048 | 4.415 | FALSE |
| matrix_colMeans | 1e+03 | base | 0.0000021 | 1.333 | TRUE |
| matrix_colMeans | 1e+03 | Rfast | 0.0000016 | 1.000 | FALSE |
| matrix_colMeans | 1e+03 | collapse | 0.0000021 | 1.308 | FALSE |
| matrix_colVar | 1e+03 | base_apply | 0.0000798 | 12.270 | TRUE |
| matrix_colVar | 1e+03 | Rfast | 0.0000065 | 1.000 | FALSE |
| matrix_colVar | 1e+03 | collapse | 0.0000081 | 1.249 | FALSE |
| matrix_rowVar | 1e+03 | base_apply | 0.0002992 | 123.700 | TRUE |
| matrix_rowVar | 1e+03 | Rfast | 0.0000024 | 1.000 | FALSE |
| matrix_rowVar | 1e+03 | collapse_t | 0.0000071 | 2.932 | FALSE |
| matrix_colMedian | 1e+03 | base_apply | 0.0002965 | 87.670 | TRUE |
| matrix_colMedian | 1e+03 | Rfast | 0.0000034 | 1.000 | TRUE |
| matrix_colMedian | 1e+03 | collapse | 0.0000044 | 1.309 | TRUE |
| matrix_rowMedian | 1e+03 | base_apply | 0.0011500 | 167.400 | TRUE |
| matrix_rowMedian | 1e+03 | Rfast | 0.0000140 | 2.045 | FALSE |
| matrix_rowMedian | 1e+03 | collapse_t | 0.0000069 | 1.000 | FALSE |
| matrix_colMeans_NA | 1e+03 | base | 0.0000027 | 1.558 | TRUE |
| matrix_colMeans_NA | 1e+03 | collapse | 0.0000020 | 1.116 | FALSE |
| matrix_colMeans_NA | 1e+03 | Rfast_nonNA_unsafe | 0.0000018 | 1.000 | FALSE |
| matrix_rowSums | 1e+05 | base | 0.0000173 | 1.048 | TRUE |
| matrix_rowSums | 1e+05 | Rfast | 0.0000165 | 1.000 | TRUE |
| matrix_rowSums | 1e+05 | collapse_t | 0.0003182 | 19.280 | FALSE |
| matrix_rowSums | 1e+05 | kit_psum | 0.0007722 | 46.790 | TRUE |
| matrix_rowMeans | 1e+05 | base | 0.0000176 | 1.007 | TRUE |
| matrix_rowMeans | 1e+05 | Rfast | 0.0000175 | 1.000 | TRUE |
| matrix_rowMeans | 1e+05 | collapse_t | 0.0001649 | 9.430 | FALSE |
| matrix_colSums | 1e+05 | base | 0.0001145 | 3.352 | TRUE |
| matrix_colSums | 1e+05 | Rfast | 0.0000342 | 1.000 | FALSE |
| matrix_colSums | 1e+05 | collapse | 0.0000719 | 2.106 | FALSE |
| matrix_colMeans | 1e+05 | base | 0.0000663 | 1.900 | TRUE |
| matrix_colMeans | 1e+05 | Rfast | 0.0000349 | 1.000 | FALSE |
| matrix_colMeans | 1e+05 | collapse | 0.0000368 | 1.054 | FALSE |
| matrix_colVar | 1e+05 | base_apply | 0.0009586 | 7.451 | TRUE |
| matrix_colVar | 1e+05 | Rfast | 0.0001287 | 1.000 | FALSE |
| matrix_colVar | 1e+05 | collapse | 0.0001963 | 1.526 | FALSE |
| matrix_rowVar | 1e+05 | base_apply | 0.0036600 | 13.750 | TRUE |
| matrix_rowVar | 1e+05 | Rfast | 0.0002661 | 1.000 | FALSE |
| matrix_rowVar | 1e+05 | collapse_t | 0.0003016 | 1.133 | FALSE |
| matrix_colMedian | 1e+05 | base_apply | 0.0027910 | 3.669 | TRUE |
| matrix_colMedian | 1e+05 | Rfast | 0.0007829 | 1.029 | TRUE |
| matrix_colMedian | 1e+05 | collapse | 0.0007608 | 1.000 | TRUE |
| matrix_rowMedian | 1e+05 | base_apply | 0.0141900 | 17.090 | TRUE |
| matrix_rowMedian | 1e+05 | Rfast | 0.0008305 | 1.000 | FALSE |
| matrix_rowMedian | 1e+05 | collapse_t | 0.0010630 | 1.280 | FALSE |
| matrix_colMeans_NA | 1e+05 | base | 0.0001932 | 2.860 | TRUE |
| matrix_colMeans_NA | 1e+05 | collapse | 0.0001001 | 1.482 | FALSE |
| matrix_colMeans_NA | 1e+05 | Rfast_nonNA_unsafe | 0.0000676 | 1.000 | FALSE |
| matrix_rowSums | 1e+07 | base | 0.0019740 | 1.031 | TRUE |
| matrix_rowSums | 1e+07 | Rfast | 0.0019150 | 1.000 | TRUE |
| matrix_rowSums | 1e+07 | collapse_t | 0.0253300 | 13.230 | FALSE |
| matrix_rowSums | 1e+07 | kit_psum | 0.1361000 | 71.080 | TRUE |
| matrix_rowMeans | 1e+07 | base | 0.0075950 | 1.426 | TRUE |
| matrix_rowMeans | 1e+07 | Rfast | 0.0053270 | 1.000 | TRUE |
| matrix_rowMeans | 1e+07 | collapse_t | 0.0356400 | 6.691 | FALSE |
| matrix_colSums | 1e+07 | base | 0.0120200 | 4.740 | TRUE |
| matrix_colSums | 1e+07 | Rfast | 0.0054030 | 2.131 | FALSE |
| matrix_colSums | 1e+07 | collapse | 0.0025360 | 1.000 | FALSE |
| matrix_colMeans | 1e+07 | base | 0.0157300 | 3.083 | TRUE |
| matrix_colMeans | 1e+07 | Rfast | 0.0051030 | 1.000 | FALSE |
| matrix_colMeans | 1e+07 | collapse | 0.0095550 | 1.873 | FALSE |
| matrix_colVar | 1e+07 | base_apply | 0.0999100 | 5.476 | TRUE |
| matrix_colVar | 1e+07 | Rfast | 0.0182500 | 1.000 | FALSE |
| matrix_colVar | 1e+07 | collapse | 0.0378800 | 2.076 | FALSE |
| matrix_rowVar | 1e+07 | base_apply | 0.5208000 | 24.800 | TRUE |
| matrix_rowVar | 1e+07 | Rfast | 0.0210000 | 1.000 | FALSE |
| matrix_rowVar | 1e+07 | collapse_t | 0.0417200 | 1.987 | FALSE |
| matrix_colMedian | 1e+07 | base_apply | 0.2198000 | 2.673 | TRUE |
| matrix_colMedian | 1e+07 | Rfast | 0.0822300 | 1.000 | TRUE |
| matrix_colMedian | 1e+07 | collapse | 0.0846600 | 1.030 | TRUE |
| matrix_rowMedian | 1e+07 | base_apply | 2.6450000 | 23.700 | TRUE |
| matrix_rowMedian | 1e+07 | Rfast | 0.1116000 | 1.000 | FALSE |
| matrix_rowMedian | 1e+07 | collapse_t | 0.1901000 | 1.703 | FALSE |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b3_sortuniq.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 312 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| su_order_int | 1e+03 | base | 0.0000086 | 2.609 | TRUE |
| su_order_int | 1e+03 | base_radix | 0.0000082 | 2.491 | TRUE |
| su_order_int | 1e+03 | forder | 0.0000161 | 4.870 | TRUE |
| su_order_int | 1e+03 | collapse_radixorder | 0.0000033 | 1.000 | FALSE |
| su_order_int | 1e+03 | Rfast_Order | 0.0000311 | 9.435 | FALSE |
| su_order_int | 1e+03 | Rfast_Order_stable | 0.0000699 | 21.170 | TRUE |
| su_sort_int | 1e+03 | base | 0.0000160 | 3.505 | TRUE |
| su_sort_int | 1e+03 | base_radix | 0.0000164 | 3.613 | TRUE |
| su_sort_int | 1e+03 | DT_forder_idx | 0.0000172 | 3.770 | TRUE |
| su_sort_int | 1e+03 | collapse_idx | 0.0000046 | 1.000 | TRUE |
| su_sort_int | 1e+03 | Rfast_Sort | 0.0000072 | 1.590 | TRUE |
| su_sort_int | 1e+03 | kit_psort | 0.0000338 | 7.423 | TRUE |
| su_unique_int | 1e+03 | base | 0.0000062 | 3.565 | TRUE |
| su_unique_int | 1e+03 | collapse_funique | 0.0000017 | 1.000 | TRUE |
| su_unique_int | 1e+03 | kit_funique | 0.0000019 | 1.094 | TRUE |
| su_unique_int | 1e+03 | DT_unique | 0.0000724 | 41.580 | TRUE |
| su_unique_int | 1e+03 | Rfast_sort_unique_SORTED | 0.0000019 | 1.082 | FALSE |
| su_uniqueN_int | 1e+03 | base | 0.0000066 | 5.458 | TRUE |
| su_uniqueN_int | 1e+03 | DT_uniqueN | 0.0000086 | 7.085 | TRUE |
| su_uniqueN_int | 1e+03 | collapse_fnunique | 0.0000013 | 1.051 | TRUE |
| su_uniqueN_int | 1e+03 | kit_uniqLen | 0.0000012 | 1.000 | TRUE |
| su_duplicated_int | 1e+03 | base | 0.0000065 | 4.609 | TRUE |
| su_duplicated_int | 1e+03 | collapse_fduplicated | 0.0000015 | 1.058 | TRUE |
| su_duplicated_int | 1e+03 | kit_fduplicated | 0.0000014 | 1.000 | TRUE |
| su_match_int | 1e+03 | base | 0.0000033 | 2.338 | TRUE |
| su_match_int | 1e+03 | collapse_fmatch | 0.0000014 | 1.000 | TRUE |
| su_match_int | 1e+03 | Rfast_Match_NOT_dropin | 0.0000074 | 5.338 | FALSE |
| su_in_int | 1e+03 | base | 0.0000041 | 1.623 | TRUE |
| su_in_int | 1e+03 | collapse_fmatch_in | 0.0000025 | 1.000 | TRUE |
| su_count_int | 1e+03 | base_table | 0.0000504 | 19.520 | TRUE |
| su_count_int | 1e+03 | collapse_qtab | 0.0000116 | 4.508 | TRUE |
| su_count_int | 1e+03 | collapse_fcount | 0.0000125 | 4.849 | TRUE |
| su_count_int | 1e+03 | kit_countOccur | 0.0000026 | 1.000 | TRUE |
| su_count_int | 1e+03 | DT_N_by | 0.0002142 | 82.930 | TRUE |
| su_count_int | 1e+03 | Rfast_Table | 0.0000278 | 10.770 | TRUE |
| su_order_int | 1e+05 | base | 0.0002034 | 1.007 | TRUE |
| su_order_int | 1e+05 | base_radix | 0.0002019 | 1.000 | TRUE |
| su_order_int | 1e+05 | forder | 0.0005478 | 2.713 | TRUE |
| su_order_int | 1e+05 | collapse_radixorder | 0.0002049 | 1.015 | FALSE |
| su_order_int | 1e+05 | Rfast_Order | 0.0082430 | 40.820 | FALSE |
| su_order_int | 1e+05 | Rfast_Order_stable | 0.0139800 | 69.220 | TRUE |
| su_sort_int | 1e+05 | base | 0.0004052 | 1.183 | TRUE |
| su_sort_int | 1e+05 | base_radix | 0.0004008 | 1.170 | TRUE |
| su_sort_int | 1e+05 | DT_forder_idx | 0.0007038 | 2.055 | TRUE |
| su_sort_int | 1e+05 | collapse_idx | 0.0003425 | 1.000 | TRUE |
| su_sort_int | 1e+05 | Rfast_Sort | 0.0012930 | 3.777 | TRUE |
| su_sort_int | 1e+05 | kit_psort | 0.0004166 | 1.216 | TRUE |
| su_unique_int | 1e+05 | base | 0.0016650 | 12.730 | TRUE |
| su_unique_int | 1e+05 | collapse_funique | 0.0010330 | 7.900 | TRUE |
| su_unique_int | 1e+05 | kit_funique | 0.0009735 | 7.442 | TRUE |
| su_unique_int | 1e+05 | DT_unique | 0.0009388 | 7.177 | TRUE |
| su_unique_int | 1e+05 | Rfast_sort_unique_SORTED | 0.0001308 | 1.000 | FALSE |
| su_uniqueN_int | 1e+05 | base | 0.0016420 | 2.969 | TRUE |
| su_uniqueN_int | 1e+05 | DT_uniqueN | 0.0005531 | 1.000 | TRUE |
| su_uniqueN_int | 1e+05 | collapse_fnunique | 0.0008788 | 1.589 | TRUE |
| su_uniqueN_int | 1e+05 | kit_uniqLen | 0.0009912 | 1.792 | TRUE |
| su_duplicated_int | 1e+05 | base | 0.0015890 | 1.723 | TRUE |
| su_duplicated_int | 1e+05 | collapse_fduplicated | 0.0009543 | 1.035 | TRUE |
| su_duplicated_int | 1e+05 | kit_fduplicated | 0.0009224 | 1.000 | TRUE |
| su_match_int | 1e+05 | base | 0.0013400 | 1.575 | TRUE |
| su_match_int | 1e+05 | collapse_fmatch | 0.0008503 | 1.000 | TRUE |
| su_match_int | 1e+05 | Rfast_Match_NOT_dropin | 0.0045090 | 5.302 | FALSE |
| su_in_int | 1e+05 | base | 0.0014210 | 1.488 | TRUE |
| su_in_int | 1e+05 | collapse_fmatch_in | 0.0009550 | 1.000 | TRUE |
| su_count_int | 1e+05 | base_table | 0.0046640 | 22.970 | TRUE |
| su_count_int | 1e+05 | collapse_qtab | 0.0004275 | 2.106 | TRUE |
| su_count_int | 1e+05 | collapse_fcount | 0.0002031 | 1.000 | TRUE |
| su_count_int | 1e+05 | kit_countOccur | 0.0011160 | 5.494 | TRUE |
| su_count_int | 1e+05 | DT_N_by | 0.0014110 | 6.949 | TRUE |
| su_count_int | 1e+05 | Rfast_Table | 0.0039110 | 19.260 | TRUE |
| su_order_int | 1e+07 | base | 0.0682600 | 1.000 | TRUE |
| su_order_int | 1e+07 | base_radix | 0.0685000 | 1.004 | TRUE |
| su_order_int | 1e+07 | forder | 0.2522000 | 3.694 | TRUE |
| su_order_int | 1e+07 | collapse_radixorder | 0.0975400 | 1.429 | FALSE |
| su_order_int | 1e+07 | Rfast_Order | 1.8380000 | 26.920 | FALSE |
| su_order_int | 1e+07 | Rfast_Order_stable | 1.9360000 | 28.360 | TRUE |
| su_sort_int | 1e+07 | base | 0.1572000 | 1.322 | TRUE |
| su_sort_int | 1e+07 | base_radix | 0.1570000 | 1.320 | TRUE |
| su_sort_int | 1e+07 | DT_forder_idx | 0.2999000 | 2.522 | TRUE |
| su_sort_int | 1e+07 | collapse_idx | 0.1189000 | 1.000 | TRUE |
| su_sort_int | 1e+07 | Rfast_Sort | 0.1769000 | 1.488 | TRUE |
| su_sort_int | 1e+07 | kit_psort | 0.1620000 | 1.363 | TRUE |
| su_unique_int | 1e+07 | base | 0.2587000 | 14.220 | TRUE |
| su_unique_int | 1e+07 | collapse_funique | 0.0783300 | 4.305 | TRUE |
| su_unique_int | 1e+07 | kit_funique | 0.0750100 | 4.123 | TRUE |
| su_unique_int | 1e+07 | DT_unique | 0.2761000 | 15.180 | TRUE |
| su_unique_int | 1e+07 | Rfast_sort_unique_SORTED | 0.0181900 | 1.000 | FALSE |
| su_uniqueN_int | 1e+07 | base | 0.2701000 | 4.250 | TRUE |
| su_uniqueN_int | 1e+07 | DT_uniqueN | 0.2648000 | 4.168 | TRUE |
| su_uniqueN_int | 1e+07 | collapse_fnunique | 0.0672600 | 1.059 | TRUE |
| su_uniqueN_int | 1e+07 | kit_uniqLen | 0.0635400 | 1.000 | TRUE |
| su_duplicated_int | 1e+07 | base | 0.2643000 | 3.790 | TRUE |
| su_duplicated_int | 1e+07 | collapse_fduplicated | 0.0697400 | 1.000 | TRUE |
| su_duplicated_int | 1e+07 | kit_fduplicated | 0.0710500 | 1.019 | TRUE |
| su_match_int | 1e+07 | base | 0.1126000 | 1.340 | TRUE |
| su_match_int | 1e+07 | collapse_fmatch | 0.0840700 | 1.000 | TRUE |
| su_match_int | 1e+07 | Rfast_Match_NOT_dropin | 0.9450000 | 11.240 | FALSE |
| su_in_int | 1e+07 | base | 0.1188000 | 1.276 | TRUE |
| su_in_int | 1e+07 | collapse_fmatch_in | 0.0931000 | 1.000 | TRUE |
| su_count_int | 1e+07 | base_table | 0.5854000 | 9.152 | TRUE |
| su_count_int | 1e+07 | collapse_qtab | 0.1119000 | 1.749 | TRUE |
| su_count_int | 1e+07 | collapse_fcount | 0.0639600 | 1.000 | TRUE |
| su_count_int | 1e+07 | kit_countOccur | 0.1316000 | 2.057 | TRUE |
| su_count_int | 1e+07 | DT_N_by | 0.4375000 | 6.841 | TRUE |
| su_count_int | 1e+07 | Rfast_Table | 1.0190000 | 15.930 | TRUE |
| su_order_dbl | 1e+03 | base | 0.0000177 | 1.552 | TRUE |
| su_order_dbl | 1e+03 | base_radix | 0.0000171 | 1.504 | TRUE |
| su_order_dbl | 1e+03 | forder | 0.0000807 | 7.083 | TRUE |
| su_order_dbl | 1e+03 | collapse_radixorder | 0.0000114 | 1.000 | FALSE |
| su_order_dbl | 1e+03 | Rfast_Order | 0.0000386 | 3.388 | FALSE |
| su_order_dbl | 1e+03 | Rfast_Order_stable | 0.0000721 | 6.329 | TRUE |
| su_sort_dbl | 1e+03 | base | 0.0000247 | 3.149 | TRUE |
| su_sort_dbl | 1e+03 | base_radix | 0.0000255 | 3.245 | TRUE |
| su_sort_dbl | 1e+03 | DT_forder_idx | 0.0000843 | 10.730 | TRUE |
| su_sort_dbl | 1e+03 | collapse_idx | 0.0000129 | 1.642 | TRUE |
| su_sort_dbl | 1e+03 | Rfast_Sort | 0.0000079 | 1.000 | TRUE |
| su_sort_dbl | 1e+03 | kit_psort | 0.0000426 | 5.426 | TRUE |
| su_unique_dbl | 1e+03 | base | 0.0000103 | 1.809 | TRUE |
| su_unique_dbl | 1e+03 | collapse_funique | 0.0000059 | 1.036 | TRUE |
| su_unique_dbl | 1e+03 | kit_funique | 0.0000057 | 1.000 | TRUE |
| su_unique_dbl | 1e+03 | DT_unique | 0.0001596 | 28.010 | TRUE |
| su_unique_dbl | 1e+03 | Rfast_sort_unique_SORTED | 0.0000089 | 1.558 | FALSE |
| su_uniqueN_dbl | 1e+03 | base | 0.0000090 | 5.176 | TRUE |
| su_uniqueN_dbl | 1e+03 | DT_uniqueN | 0.0000817 | 46.860 | TRUE |
| su_uniqueN_dbl | 1e+03 | collapse_fnunique | 0.0000017 | 1.000 | TRUE |
| su_uniqueN_dbl | 1e+03 | kit_uniqLen | 0.0000039 | 2.212 | TRUE |
| su_duplicated_dbl | 1e+03 | base | 0.0000101 | 2.325 | TRUE |
| su_duplicated_dbl | 1e+03 | collapse_fduplicated | 0.0000043 | 1.000 | TRUE |
| su_duplicated_dbl | 1e+03 | kit_fduplicated | 0.0000110 | 2.542 | TRUE |
| su_match_dbl | 1e+03 | base | 0.0000136 | 4.130 | TRUE |
| su_match_dbl | 1e+03 | collapse_fmatch | 0.0000033 | 1.000 | TRUE |
| su_match_dbl | 1e+03 | Rfast_Match_NOT_dropin | 0.0000092 | 2.789 | FALSE |
| su_in_dbl | 1e+03 | base | 0.0000145 | 3.179 | TRUE |
| su_in_dbl | 1e+03 | collapse_fmatch_in | 0.0000046 | 1.000 | TRUE |
| su_count_dbl | 1e+03 | base_table | 0.0005315 | 82.570 | TRUE |
| su_count_dbl | 1e+03 | collapse_qtab | 0.0000274 | 4.258 | TRUE |
| su_count_dbl | 1e+03 | collapse_fcount | 0.0000162 | 2.516 | TRUE |
| su_count_dbl | 1e+03 | kit_countOccur | 0.0000064 | 1.000 | TRUE |
| su_count_dbl | 1e+03 | DT_N_by | 0.0003055 | 47.450 | TRUE |
| su_count_dbl | 1e+03 | Rfast_Table | 0.0002152 | 33.430 | TRUE |
| su_order_dbl | 1e+05 | base | 0.0009477 | 1.028 | TRUE |
| su_order_dbl | 1e+05 | base_radix | 0.0009397 | 1.019 | TRUE |
| su_order_dbl | 1e+05 | forder | 0.0036500 | 3.959 | TRUE |
| su_order_dbl | 1e+05 | collapse_radixorder | 0.0009220 | 1.000 | FALSE |
| su_order_dbl | 1e+05 | Rfast_Order | 0.0070010 | 7.593 | FALSE |
| su_order_dbl | 1e+05 | Rfast_Order_stable | 0.0133700 | 14.500 | TRUE |
| su_sort_dbl | 1e+05 | base | 0.0011740 | 1.030 | TRUE |
| su_sort_dbl | 1e+05 | base_radix | 0.0011830 | 1.038 | TRUE |
| su_sort_dbl | 1e+05 | DT_forder_idx | 0.0039660 | 3.479 | TRUE |
| su_sort_dbl | 1e+05 | collapse_idx | 0.0011400 | 1.000 | TRUE |
| su_sort_dbl | 1e+05 | Rfast_Sort | 0.0012750 | 1.118 | TRUE |
| su_sort_dbl | 1e+05 | kit_psort | 0.0012510 | 1.097 | TRUE |
| su_unique_dbl | 1e+05 | base | 0.0007286 | 2.048 | TRUE |
| su_unique_dbl | 1e+05 | collapse_funique | 0.0003557 | 1.000 | FALSE |
| su_unique_dbl | 1e+05 | kit_funique | 0.0003738 | 1.051 | FALSE |
| su_unique_dbl | 1e+05 | DT_unique | 0.0042220 | 11.870 | TRUE |
| su_unique_dbl | 1e+05 | Rfast_sort_unique_SORTED | 0.0013160 | 3.699 | FALSE |
| su_uniqueN_dbl | 1e+05 | base | 0.0007891 | 5.026 | TRUE |
| su_uniqueN_dbl | 1e+05 | DT_uniqueN | 0.0038940 | 24.800 | TRUE |
| su_uniqueN_dbl | 1e+05 | collapse_fnunique | 0.0001570 | 1.000 | TRUE |
| su_uniqueN_dbl | 1e+05 | kit_uniqLen | 0.0003096 | 1.972 | FALSE |
| su_duplicated_dbl | 1e+05 | base | 0.0006830 | 2.161 | TRUE |
| su_duplicated_dbl | 1e+05 | collapse_fduplicated | 0.0003183 | 1.007 | FALSE |
| su_duplicated_dbl | 1e+05 | kit_fduplicated | 0.0003161 | 1.000 | FALSE |
| su_match_dbl | 1e+05 | base | 0.0010220 | 2.739 | TRUE |
| su_match_dbl | 1e+05 | collapse_fmatch | 0.0003733 | 1.000 | TRUE |
| su_match_dbl | 1e+05 | Rfast_Match_NOT_dropin | 0.0050870 | 13.630 | FALSE |
| su_in_dbl | 1e+05 | base | 0.0011050 | 2.428 | TRUE |
| su_in_dbl | 1e+05 | collapse_fmatch_in | 0.0004550 | 1.000 | TRUE |
| su_count_dbl | 1e+05 | base_table | 0.0279500 | 99.580 | TRUE |
| su_count_dbl | 1e+05 | collapse_qtab | 0.0013280 | 4.733 | FALSE |
| su_count_dbl | 1e+05 | collapse_fcount | 0.0002806 | 1.000 | TRUE |
| su_count_dbl | 1e+05 | kit_countOccur | 0.0004208 | 1.500 | FALSE |
| su_count_dbl | 1e+05 | DT_N_by | 0.0050410 | 17.960 | TRUE |
| su_count_dbl | 1e+05 | Rfast_Table | 0.0026640 | 9.492 | TRUE |
| su_order_dbl | 1e+07 | base | 0.2739000 | 1.009 | TRUE |
| su_order_dbl | 1e+07 | base_radix | 0.2841000 | 1.046 | TRUE |
| su_order_dbl | 1e+07 | forder | 0.3788000 | 1.395 | TRUE |
| su_order_dbl | 1e+07 | collapse_radixorder | 0.2716000 | 1.000 | FALSE |
| su_order_dbl | 1e+07 | Rfast_Order | 1.2610000 | 4.643 | FALSE |
| su_order_dbl | 1e+07 | Rfast_Order_stable | 1.5350000 | 5.654 | TRUE |
| su_sort_dbl | 1e+07 | base | 0.3715000 | 3.711 | TRUE |
| su_sort_dbl | 1e+07 | base_radix | 0.3785000 | 3.781 | TRUE |
| su_sort_dbl | 1e+07 | DT_forder_idx | 0.4255000 | 4.250 | TRUE |
| su_sort_dbl | 1e+07 | collapse_idx | 0.3278000 | 3.275 | TRUE |
| su_sort_dbl | 1e+07 | Rfast_Sort | 0.1001000 | 1.000 | TRUE |
| su_sort_dbl | 1e+07 | kit_psort | 0.3738000 | 3.734 | TRUE |
| su_unique_dbl | 1e+07 | base | 0.0815300 | 2.289 | TRUE |
| su_unique_dbl | 1e+07 | collapse_funique | 0.0367200 | 1.031 | FALSE |
| su_unique_dbl | 1e+07 | kit_funique | 0.0356300 | 1.000 | FALSE |
| su_unique_dbl | 1e+07 | DT_unique | 0.3364000 | 9.444 | TRUE |
| su_unique_dbl | 1e+07 | Rfast_sort_unique_SORTED | 0.1025000 | 2.877 | FALSE |
| su_uniqueN_dbl | 1e+07 | base | 0.0784900 | 4.350 | TRUE |
| su_uniqueN_dbl | 1e+07 | DT_uniqueN | 0.3551000 | 19.680 | TRUE |
| su_uniqueN_dbl | 1e+07 | collapse_fnunique | 0.0180400 | 1.000 | TRUE |
| su_uniqueN_dbl | 1e+07 | kit_uniqLen | 0.0328400 | 1.820 | FALSE |
| su_duplicated_dbl | 1e+07 | base | 0.0824200 | 2.535 | TRUE |
| su_duplicated_dbl | 1e+07 | collapse_fduplicated | 0.0325100 | 1.000 | FALSE |
| su_duplicated_dbl | 1e+07 | kit_fduplicated | 0.0325500 | 1.001 | FALSE |
| su_match_dbl | 1e+07 | base | 0.0411400 | 3.168 | TRUE |
| su_match_dbl | 1e+07 | collapse_fmatch | 0.0129800 | 1.000 | TRUE |
| su_match_dbl | 1e+07 | Rfast_Match_NOT_dropin | 0.7305000 | 56.260 | FALSE |
| su_in_dbl | 1e+07 | base | 0.0589100 | 1.969 | TRUE |
| su_in_dbl | 1e+07 | collapse_fmatch_in | 0.0299200 | 1.000 | TRUE |
| su_count_dbl | 1e+07 | base_table | 2.6230000 | 107.500 | TRUE |
| su_count_dbl | 1e+07 | collapse_qtab | 0.4072000 | 16.690 | FALSE |
| su_count_dbl | 1e+07 | collapse_fcount | 0.0244000 | 1.000 | TRUE |
| su_count_dbl | 1e+07 | kit_countOccur | 0.0359800 | 1.474 | FALSE |
| su_count_dbl | 1e+07 | DT_N_by | 0.4034000 | 16.530 | TRUE |
| su_count_dbl | 1e+07 | Rfast_Table | 0.0709500 | 2.907 | TRUE |
| su_order_chr | 1e+03 | base | 0.0007304 | 72.860 | TRUE |
| su_order_chr | 1e+03 | base_radix | 0.0000136 | 1.352 | FALSE |
| su_order_chr | 1e+03 | forder | 0.0000308 | 3.078 | FALSE |
| su_order_chr | 1e+03 | collapse_radixorder | 0.0000100 | 1.000 | FALSE |
| su_order_chr | 1e+03 | Rfast_Order | 0.0000761 | 7.595 | FALSE |
| su_order_chr | 1e+03 | Rfast_Order_stable | 0.0000827 | 8.249 | FALSE |
| su_sort_chr | 1e+03 | base | 0.0005668 | 41.150 | TRUE |
| su_sort_chr | 1e+03 | base_radix | 0.0000239 | 1.738 | FALSE |
| su_sort_chr | 1e+03 | DT_forder_idx | 0.0000360 | 2.612 | FALSE |
| su_sort_chr | 1e+03 | collapse_idx | 0.0000138 | 1.000 | FALSE |
| su_sort_chr | 1e+03 | Rfast_Sort | 0.0000531 | 3.854 | FALSE |
| su_sort_chr | 1e+03 | kit_psort | 0.0000149 | 1.085 | FALSE |
| su_unique_chr | 1e+03 | base | 0.0000088 | 4.685 | TRUE |
| su_unique_chr | 1e+03 | collapse_funique | 0.0000019 | 1.000 | TRUE |
| su_unique_chr | 1e+03 | kit_funique | 0.0000019 | 1.011 | TRUE |
| su_unique_chr | 1e+03 | DT_unique | 0.0000818 | 43.380 | TRUE |
| su_uniqueN_chr | 1e+03 | base | 0.0000086 | 7.518 | TRUE |
| su_uniqueN_chr | 1e+03 | DT_uniqueN | 0.0000229 | 19.930 | TRUE |
| su_uniqueN_chr | 1e+03 | collapse_fnunique | 0.0000013 | 1.125 | TRUE |
| su_uniqueN_chr | 1e+03 | kit_uniqLen | 0.0000011 | 1.000 | TRUE |
| su_duplicated_chr | 1e+03 | base | 0.0000082 | 5.542 | TRUE |
| su_duplicated_chr | 1e+03 | collapse_fduplicated | 0.0000015 | 1.000 | TRUE |
| su_duplicated_chr | 1e+03 | kit_fduplicated | 0.0000015 | 1.000 | TRUE |
| su_match_chr | 1e+03 | base | 0.0000074 | 4.415 | TRUE |
| su_match_chr | 1e+03 | collapse_fmatch | 0.0000017 | 1.000 | TRUE |
| su_match_chr | 1e+03 | DT_chmatch | 0.0000040 | 2.402 | TRUE |
| su_in_chr | 1e+03 | base | 0.0000084 | 3.000 | TRUE |
| su_in_chr | 1e+03 | collapse_fmatch_in | 0.0000028 | 1.000 | TRUE |
| su_in_chr | 1e+03 | DT_chin | 0.0000036 | 1.309 | TRUE |
| su_count_chr | 1e+03 | base_table | 0.0000959 | 43.710 | TRUE |
| su_count_chr | 1e+03 | collapse_qtab | 0.0000168 | 7.645 | TRUE |
| su_count_chr | 1e+03 | collapse_fcount | 0.0000133 | 6.084 | TRUE |
| su_count_chr | 1e+03 | kit_countOccur | 0.0000022 | 1.000 | TRUE |
| su_count_chr | 1e+03 | DT_N_by | 0.0002233 | 101.800 | TRUE |
| su_order_chr | 1e+05 | base | 0.1607000 | 163.700 | TRUE |
| su_order_chr | 1e+05 | base_radix | 0.0010110 | 1.030 | FALSE |
| su_order_chr | 1e+05 | forder | 0.0020440 | 2.083 | FALSE |
| su_order_chr | 1e+05 | collapse_radixorder | 0.0009813 | 1.000 | FALSE |
| su_order_chr | 1e+05 | Rfast_Order | 0.0059410 | 6.055 | FALSE |
| su_order_chr | 1e+05 | Rfast_Order_stable | 0.0072980 | 7.437 | FALSE |
| su_sort_chr | 1e+05 | base | 0.1389000 | 98.440 | TRUE |
| su_sort_chr | 1e+05 | base_radix | 0.0014820 | 1.050 | FALSE |
| su_sort_chr | 1e+05 | DT_forder_idx | 0.0024620 | 1.744 | FALSE |
| su_sort_chr | 1e+05 | collapse_idx | 0.0014110 | 1.000 | FALSE |
| su_sort_chr | 1e+05 | Rfast_Sort | 0.0114100 | 8.082 | FALSE |
| su_sort_chr | 1e+05 | kit_psort | 0.0014890 | 1.055 | FALSE |
| su_unique_chr | 1e+05 | base | 0.0008197 | 4.691 | TRUE |
| su_unique_chr | 1e+05 | collapse_funique | 0.0001936 | 1.108 | TRUE |
| su_unique_chr | 1e+05 | kit_funique | 0.0001747 | 1.000 | TRUE |
| su_unique_chr | 1e+05 | DT_unique | 0.0019190 | 10.980 | TRUE |
| su_uniqueN_chr | 1e+05 | base | 0.0008363 | 7.113 | TRUE |
| su_uniqueN_chr | 1e+05 | DT_uniqueN | 0.0021710 | 18.470 | TRUE |
| su_uniqueN_chr | 1e+05 | collapse_fnunique | 0.0001176 | 1.000 | TRUE |
| su_uniqueN_chr | 1e+05 | kit_uniqLen | 0.0001261 | 1.072 | TRUE |
| su_duplicated_chr | 1e+05 | base | 0.0007290 | 5.863 | TRUE |
| su_duplicated_chr | 1e+05 | collapse_fduplicated | 0.0001283 | 1.032 | TRUE |
| su_duplicated_chr | 1e+05 | kit_fduplicated | 0.0001243 | 1.000 | TRUE |
| su_match_chr | 1e+05 | base | 0.0009682 | 6.124 | TRUE |
| su_match_chr | 1e+05 | collapse_fmatch | 0.0001581 | 1.000 | TRUE |
| su_match_chr | 1e+05 | DT_chmatch | 0.0006188 | 3.914 | TRUE |
| su_in_chr | 1e+05 | base | 0.0010320 | 4.572 | TRUE |
| su_in_chr | 1e+05 | collapse_fmatch_in | 0.0002258 | 1.000 | TRUE |
| su_in_chr | 1e+05 | DT_chin | 0.0006114 | 2.708 | TRUE |
| su_count_chr | 1e+05 | base_table | 0.0142100 | 62.240 | TRUE |
| su_count_chr | 1e+05 | collapse_qtab | 0.0010860 | 4.758 | TRUE |
| su_count_chr | 1e+05 | collapse_fcount | 0.0002456 | 1.076 | TRUE |
| su_count_chr | 1e+05 | kit_countOccur | 0.0002283 | 1.000 | TRUE |
| su_count_chr | 1e+05 | DT_N_by | 0.0022860 | 10.010 | TRUE |
| su_order_chr | 2e+06 | base | 6.5650000 | 198.200 | TRUE |
| su_order_chr | 2e+06 | base_radix | 0.0331300 | 1.000 | FALSE |
| su_order_chr | 2e+06 | forder | 0.0851000 | 2.569 | FALSE |
| su_order_chr | 2e+06 | collapse_radixorder | 0.0334700 | 1.011 | FALSE |
| su_order_chr | 2e+06 | Rfast_Order | 0.1478000 | 4.462 | FALSE |
| su_order_chr | 2e+06 | Rfast_Order_stable | 0.1731000 | 5.224 | FALSE |
| su_sort_chr | 2e+06 | base | 4.7350000 | 76.590 | TRUE |
| su_sort_chr | 2e+06 | base_radix | 0.0618200 | 1.000 | FALSE |
| su_sort_chr | 2e+06 | DT_forder_idx | 0.1210000 | 1.958 | FALSE |
| su_sort_chr | 2e+06 | collapse_idx | 0.1077000 | 1.742 | FALSE |
| su_sort_chr | 2e+06 | Rfast_Sort | 0.3001000 | 4.855 | FALSE |
| su_sort_chr | 2e+06 | kit_psort | 0.0632800 | 1.024 | FALSE |
| su_unique_chr | 2e+06 | base | 0.0473100 | 3.213 | TRUE |
| su_unique_chr | 2e+06 | collapse_funique | 0.0150000 | 1.018 | TRUE |
| su_unique_chr | 2e+06 | kit_funique | 0.0147300 | 1.000 | TRUE |
| su_unique_chr | 2e+06 | DT_unique | 0.0769100 | 5.222 | TRUE |
| su_uniqueN_chr | 2e+06 | base | 0.0463400 | 1.885 | TRUE |
| su_uniqueN_chr | 2e+06 | DT_uniqueN | 0.1070000 | 4.353 | TRUE |
| su_uniqueN_chr | 2e+06 | collapse_fnunique | 0.0245900 | 1.000 | TRUE |
| su_uniqueN_chr | 2e+06 | kit_uniqLen | 0.0270900 | 1.102 | TRUE |
| su_duplicated_chr | 2e+06 | base | 0.0320300 | 6.035 | TRUE |
| su_duplicated_chr | 2e+06 | collapse_fduplicated | 0.0053080 | 1.000 | TRUE |
| su_duplicated_chr | 2e+06 | kit_fduplicated | 0.0054940 | 1.035 | TRUE |
| su_match_chr | 2e+06 | base | 0.0525400 | 3.003 | TRUE |
| su_match_chr | 2e+06 | collapse_fmatch | 0.0174900 | 1.000 | TRUE |
| su_match_chr | 2e+06 | DT_chmatch | 0.0221500 | 1.266 | TRUE |
| su_in_chr | 2e+06 | base | 0.0783100 | 3.992 | TRUE |
| su_in_chr | 2e+06 | collapse_fmatch_in | 0.0196200 | 1.000 | TRUE |
| su_in_chr | 2e+06 | DT_chin | 0.0246600 | 1.257 | TRUE |
| su_count_chr | 2e+06 | base_table | 0.5900000 | 51.320 | TRUE |
| su_count_chr | 2e+06 | collapse_qtab | 0.0380300 | 3.309 | TRUE |
| su_count_chr | 2e+06 | collapse_fcount | 0.0115000 | 1.000 | TRUE |
| su_count_chr | 2e+06 | kit_countOccur | 0.0140700 | 1.224 | TRUE |
| su_count_chr | 2e+06 | DT_N_by | 0.0972200 | 8.457 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b4_ifelse_lag.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 60 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| ifelse2 | 1e+03 | base_ifelse | 0.0000146 | 5.361 | TRUE |
| ifelse2 | 1e+03 | dplyr_if_else | 0.0000045 | 1.639 | TRUE |
| ifelse2 | 1e+03 | DT_fifelse | 0.0000027 | 1.000 | TRUE |
| ifelse2 | 1e+03 | kit_iif | 0.0000028 | 1.015 | TRUE |
| case3 | 1e+03 | base_nested | 0.0000915 | 4.595 | TRUE |
| case3 | 1e+03 | dplyr_case_when | 0.0000992 | 4.981 | TRUE |
| case3 | 1e+03 | DT_fcase | 0.0000312 | 1.568 | TRUE |
| case3 | 1e+03 | kit_nif | 0.0000199 | 1.000 | TRUE |
| lag_ungrouped | 1e+03 | base | 0.0000033 | 1.000 | TRUE |
| lag_ungrouped | 1e+03 | dplyr_lag | 0.0000147 | 4.426 | TRUE |
| lag_ungrouped | 1e+03 | DT_shift | 0.0000057 | 1.716 | TRUE |
| lag_ungrouped | 1e+03 | collapse_flag | 0.0000035 | 1.062 | TRUE |
| lag_grouped | 1e+03 | dplyr | 0.0005152 | 88.190 | TRUE |
| lag_grouped | 1e+03 | DT | 0.0002080 | 35.590 | TRUE |
| lag_grouped | 1e+03 | collapse_flag | 0.0000058 | 1.000 | TRUE |
| lag_grouped | 1e+03 | base_ave | 0.0001160 | 19.850 | TRUE |
| cumsum_grouped | 1e+03 | base_ave_cumsum | 0.0001044 | 14.720 | TRUE |
| cumsum_grouped | 1e+03 | dplyr | 0.0004101 | 57.820 | TRUE |
| cumsum_grouped | 1e+03 | DT | 0.0001825 | 25.730 | TRUE |
| cumsum_grouped | 1e+03 | collapse_fcumsum | 0.0000071 | 1.000 | TRUE |
| ifelse2 | 1e+05 | base_ifelse | 0.0012940 | 7.820 | TRUE |
| ifelse2 | 1e+05 | dplyr_if_else | 0.0001670 | 1.009 | TRUE |
| ifelse2 | 1e+05 | DT_fifelse | 0.0002108 | 1.274 | TRUE |
| ifelse2 | 1e+05 | kit_iif | 0.0001655 | 1.000 | TRUE |
| case3 | 1e+05 | base_nested | 0.0037810 | 5.595 | TRUE |
| case3 | 1e+05 | dplyr_case_when | 0.0011300 | 1.672 | TRUE |
| case3 | 1e+05 | DT_fcase | 0.0011340 | 1.678 | TRUE |
| case3 | 1e+05 | kit_nif | 0.0006758 | 1.000 | TRUE |
| lag_ungrouped | 1e+05 | base | 0.0001654 | 10.160 | TRUE |
| lag_ungrouped | 1e+05 | dplyr_lag | 0.0001391 | 8.543 | TRUE |
| lag_ungrouped | 1e+05 | DT_shift | 0.0000163 | 1.000 | TRUE |
| lag_ungrouped | 1e+05 | collapse_flag | 0.0000521 | 3.200 | TRUE |
| lag_grouped | 1e+05 | dplyr | 0.0141300 | 67.850 | TRUE |
| lag_grouped | 1e+05 | DT | 0.0014360 | 6.895 | TRUE |
| lag_grouped | 1e+05 | collapse_flag | 0.0002083 | 1.000 | TRUE |
| lag_grouped | 1e+05 | base_ave | 0.0070040 | 33.630 | TRUE |
| cumsum_grouped | 1e+05 | base_ave_cumsum | 0.0063490 | 14.860 | TRUE |
| cumsum_grouped | 1e+05 | dplyr | 0.0030130 | 7.055 | TRUE |
| cumsum_grouped | 1e+05 | DT | 0.0013870 | 3.247 | TRUE |
| cumsum_grouped | 1e+05 | collapse_fcumsum | 0.0004271 | 1.000 | TRUE |
| ifelse2 | 1e+07 | base_ifelse | 0.1519000 | 12.950 | TRUE |
| ifelse2 | 1e+07 | dplyr_if_else | 0.0155500 | 1.326 | TRUE |
| ifelse2 | 1e+07 | DT_fifelse | 0.0162700 | 1.387 | TRUE |
| ifelse2 | 1e+07 | kit_iif | 0.0117200 | 1.000 | TRUE |
| case3 | 1e+07 | base_nested | 0.4592000 | 5.687 | TRUE |
| case3 | 1e+07 | dplyr_case_when | 0.1185000 | 1.467 | TRUE |
| case3 | 1e+07 | DT_fcase | 0.1151000 | 1.426 | TRUE |
| case3 | 1e+07 | kit_nif | 0.0807400 | 1.000 | TRUE |
| lag_ungrouped | 1e+07 | base | 0.0213100 | 11.980 | TRUE |
| lag_ungrouped | 1e+07 | dplyr_lag | 0.0127900 | 7.193 | TRUE |
| lag_ungrouped | 1e+07 | DT_shift | 0.0017780 | 1.000 | TRUE |
| lag_ungrouped | 1e+07 | collapse_flag | 0.0060580 | 3.406 | TRUE |
| lag_grouped | 1e+07 | dplyr | 1.8050000 | 73.540 | TRUE |
| lag_grouped | 1e+07 | DT | 0.1453000 | 5.923 | TRUE |
| lag_grouped | 1e+07 | collapse_flag | 0.0245400 | 1.000 | TRUE |
| lag_grouped | 1e+07 | base_ave | 1.7040000 | 69.450 | TRUE |
| cumsum_grouped | 1e+07 | base_ave_cumsum | 1.7250000 | 41.970 | TRUE |
| cumsum_grouped | 1e+07 | dplyr | 0.5251000 | 12.780 | TRUE |
| cumsum_grouped | 1e+07 | DT | 0.1236000 | 3.008 | TRUE |
| cumsum_grouped | 1e+07 | collapse_fcumsum | 0.0411000 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b4_join_rowcount.csv` (run NA) 3 rows
</summary>

| task                  |     n |
|:----------------------|------:|
| join_dupkeys_rowcount | 1e+03 |
| join_dupkeys_rowcount | 1e+05 |
| join_dupkeys_rowcount | 2e+06 |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b4_join.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 21 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| join_left_m1 | 1e+03 | dplyr | 0.0004636 | 38.330 | TRUE |
| join_left_m1 | 1e+03 | DT | 0.0002611 | 21.590 | FALSE |
| join_left_m1 | 1e+03 | collapse | 0.0000121 | 1.000 | TRUE |
| join_left_m1 | 1e+03 | base_merge | 0.0003955 | 32.700 | TRUE |
| join_left_dupkeys | 1e+03 | dplyr | 0.0049440 | 220.300 | TRUE |
| join_left_dupkeys | 1e+03 | DT | 0.0002593 | 11.550 | FALSE |
| join_left_dupkeys | 1e+03 | collapse_multiple_TRUE | 0.0000224 | 1.000 | TRUE |
| join_left_m1 | 1e+05 | dplyr | 0.0039890 | 14.120 | TRUE |
| join_left_m1 | 1e+05 | DT | 0.0032070 | 11.360 | FALSE |
| join_left_m1 | 1e+05 | collapse | 0.0002824 | 1.000 | TRUE |
| join_left_m1 | 1e+05 | base_merge | 0.0690000 | 244.300 | TRUE |
| join_left_dupkeys | 1e+05 | dplyr | 0.0079710 | 10.240 | TRUE |
| join_left_dupkeys | 1e+05 | DT | 0.0029350 | 3.772 | FALSE |
| join_left_dupkeys | 1e+05 | collapse_multiple_TRUE | 0.0007781 | 1.000 | TRUE |
| join_left_m1 | 2e+06 | dplyr | 0.1942000 | 7.598 | TRUE |
| join_left_m1 | 2e+06 | DT | 0.0569100 | 2.227 | FALSE |
| join_left_m1 | 2e+06 | collapse | 0.0255500 | 1.000 | TRUE |
| join_left_m1 | 2e+06 | base_merge | 2.0240000 | 79.200 | TRUE |
| join_left_dupkeys | 2e+06 | dplyr | 0.0683100 | 5.396 | TRUE |
| join_left_dupkeys | 2e+06 | DT | 0.0400600 | 3.165 | FALSE |
| join_left_dupkeys | 2e+06 | collapse_multiple_TRUE | 0.0126600 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b6_envworkers.csv` (run 2026-11-03) 9 rows
</summary>

| engine | condition | OMP | RDT | MYVAR | dt_threads | dt_after_setDTthreads1 | run_date | parent_default_dt_threads |
|:---|:---|:---|:---|:---|---:|---:|:---|---:|
| mirai | none | <unset> | <unset> | <unset> | 6 | 1 | 2026-11-03 | 6 |
| crew | none | <unset> | <unset> | <unset> | 6 | 1 | 2026-11-03 | 6 |
| mirai | RDT1_only | <unset> | 1 | <unset> | 1 | 1 | 2026-11-03 | 6 |
| crew | RDT1_only | <unset> | 1 | <unset> | 1 | 1 | 2026-11-03 | 6 |
| mirai | OMP1_only | 1 | <unset> | <unset> | 1 | 1 | 2026-11-03 | 6 |
| crew | OMP1_only | 1 | <unset> | <unset> | 1 | 1 | 2026-11-03 | 6 |
| mirai | both_1_plus_MYVAR | 1 | 1 | hello | 1 | 1 | 2026-11-03 | 6 |
| crew | both_1_plus_MYVAR | 1 | 1 | hello | 1 | 1 | 2026-11-03 | 6 |
| crew | env set after worker already running (same worker reused) | <unset> | <unset> | <unset> | 1 | 1 | 2026-11-03 | 6 |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b6_identity.csv` (run NA) 38 rows
</summary>

| id | section | claim | result | detail |
|:---|:---|:---|:---|:---|
| b_fmean | 6b | fmean(x) identical to mean(x), 20 seeds of rnorm(1e6) | 0/20 identical; all.equal 20/20 | max abs diff 9.01e-17 |
| b_fsum | 6b | fsum(x) identical to sum(x), 20 seeds | 0/20 identical |  |
| b_fmean_small | 6b | fmean vs mean on x=1:10+0.1 | FALSE |  |
| grp_sum_collapse | 1 | grouped sum: collapse vs base tapply (1e6 rows, 1e3 groups) | identical=1 all.equal=1 | max abs diff 0 |
| grp_sum_data.table | 1 | grouped sum: data.table vs base tapply (1e6 rows, 1e3 groups) | identical=1 all.equal=1 | max abs diff 0 |
| grp_sum_Rfast | 1 | grouped sum: Rfast vs base tapply (1e6 rows, 1e3 groups) | identical=1 all.equal=1 | max abs diff 0 |
| grp_mean_collapse | 1 | grouped mean: collapse vs base tapply (1e6 rows, 1e3 groups) | identical=0 all.equal=1 | max abs diff 2.64e-16 |
| grp_mean_data.table | 1 | grouped mean: data.table vs base tapply (1e6 rows, 1e3 groups) | identical=0 all.equal=1 | max abs diff 2.64e-16 |
| grp_mean_Rfast | 1 | grouped mean: Rfast vs base tapply (1e6 rows, 1e3 groups) | identical=0 all.equal=1 | max abs diff 1.3e-16 |
| grp_median_collapse | 1 | grouped median: collapse vs base tapply (1e6 rows, 1e3 groups) | identical=1 all.equal=1 | max abs diff 0 |
| grp_median_data.table | 1 | grouped median: data.table vs base tapply (1e6 rows, 1e3 groups) | identical=1 all.equal=1 | max abs diff 0 |
| grp_median_Rfast | 1 | grouped median: Rfast vs base tapply (1e6 rows, 1e3 groups) | identical=1 all.equal=1 | max abs diff 0 |
| grp_q90_collapse | 1 | grouped q90: collapse vs base tapply (1e6 rows, 1e3 groups) | identical=0 all.equal=1 | max abs diff 2.22e-16 |
| grp_q90_data.table | 1 | grouped q90: data.table vs base tapply (1e6 rows, 1e3 groups) | identical=1 all.equal=1 | max abs diff 0 |
| mat_colMeans_collapse | 2 | colMeans: collapse vs base | identical=FALSE all.equal=TRUE | attributes: base names=FALSE; fast names=FALSE |
| mat_colMeans_Rfast | 2 | colMeans: Rfast vs base | identical=FALSE all.equal=TRUE | attributes: base names=FALSE; fast names=FALSE |
| mat_colSums_collapse | 2 | colSums: collapse vs base | identical=FALSE all.equal=TRUE | attributes: base names=FALSE; fast names=FALSE |
| mat_colSums_Rfast | 2 | colSums: Rfast vs base | identical=FALSE all.equal=TRUE | attributes: base names=FALSE; fast names=FALSE |
| mat_colVar_collapse | 2 | colVar: collapse vs base | identical=FALSE all.equal=TRUE | attributes: base names=FALSE; fast names=FALSE |
| mat_colVar_Rfast | 2 | colVar: Rfast vs base | identical=FALSE all.equal=TRUE | attributes: base names=FALSE; fast names=FALSE |
| join_dt_cols | 4 | left join DT yd\[xd,on=\] column order vs dplyr | k,b,a | dplyr: k,a,b |
| join_dt_rows | 4 | DT join after reordering columns equals dplyr (row order kept) | TRUE |  |
| join_collapse_equal | 4 | collapse::join identical to dplyr left_join (unique y key) | TRUE |  |
| na_fsum | pitfall | fsum(c(NA,NA)) vs sum | fsum=NA sum=NA |  |
| na_fsum_na_rm | pitfall | fsum(c(NA,1)) / mean | fsum=1 sum=NA fmean=1 mean=NA |  |
| na_allNA_group | pitfall | all-NA group mean: base tapply vs fmean vs dplyr(na.rm=TRUE) | tapply(na.rm)=NaN,1.5 fmean=NA,1.5 dplyr=NaN,1.5 |  |
| na_fcumsum | pitfall | fcumsum(c(1,NA,3)) vs cumsum | fcumsum=1,NA,4 cumsum=1,NA,NA |  |
| int_overflow | pitfall | grouped fsum integer overflow | Integer overflow in one or more groups. Integers in R are bounded between 2,147,483,647 and -2,147,483,647. The sum within each group should be in that range. | base tapply: NA with warning |
| kit_iif_types | 5 | kit::iif(c(TRUE,FALSE), 1L, 2) type mix | ERROR: 'yes' is of type integer but 'no' is of type double. Please make sure that both arguments have the same type. | fifelse: |
| fifelse_types | 5 | fifelse(c(TRUE,FALSE), 1L, 2) | numeric |  |
| ifelse_date | 5 | base ifelse drops Date class; fifelse keeps | base=numeric fifelse=Date |  |
| rfast_rng | 6c | Rfast::Rnorm after set.seed(1) vs stats::rnorm | identical to rnorm: FALSE; reproducible under set.seed: FALSE; Rnorm(seed=1) == set.seed-run: FALSE | rnorm: -0.626 0.184 -0.836 1.595 0.33 \| Rnorm: -1.068 0.289 0.99 -0.512 -0.921 |
| rfast_shuffle | 6c | Rfast::colShuffle after set.seed(1) vs sample(10) | identical: FALSE |  |
| rfast_rng_seed_sensitive | 6c | Rfast::Rnorm responds to set.seed (different seeds differ) | TRUE |  |
| mask_before | 7 | dplyr summarise(sum(x), mean(x), .by=g) with NA | sum=NA,7 mean=NA,3.5 |  |
| mask_after_all | 7 | same after set_collapse(mask='all') (dplyr verb unchanged, sum-\>fsum) | sum=8,8,8,8 mean=2.66666666666667,2.66666666666667,2.66666666666667,2.66666666666667 | na.rm=TRUE default now applies silently |
| mask_order | 7 | group order: dplyr .by (first appearance) before/after mask |  | base tapply order: a,b,c |
| mask_fsum_default_sort | 7 | collapse::fsum(x, g) group order default | a,b,c | sort=TRUE default; dplyr .by keeps appearance order |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b6_threads_linux.csv` (Linux aarch64, 12 cores, R 4.6.2; run 2026-11-03) 56 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| DT_groupby_sum | 1e+07 | threads_1 | 0.0825100 | 2.554 | TRUE |
| DT_groupby_sum | 1e+07 | threads_2 | 0.0526700 | 1.630 | TRUE |
| DT_groupby_sum | 1e+07 | threads_4 | 0.0374900 | 1.160 | TRUE |
| DT_groupby_sum | 1e+07 | threads_6 | 0.0323100 | 1.000 | TRUE |
| DT_forder_dbl | 1e+07 | threads_1 | 0.5647000 | 1.815 | TRUE |
| DT_forder_dbl | 1e+07 | threads_2 | 0.4125000 | 1.326 | TRUE |
| DT_forder_dbl | 1e+07 | threads_4 | 0.3550000 | 1.141 | TRUE |
| DT_forder_dbl | 1e+07 | threads_6 | 0.3111000 | 1.000 | TRUE |
| DT_forder_int | 1e+07 | threads_1 | 0.2735000 | 4.867 | TRUE |
| DT_forder_int | 1e+07 | threads_2 | 0.1465000 | 2.607 | TRUE |
| DT_forder_int | 1e+07 | threads_4 | 0.0786700 | 1.400 | TRUE |
| DT_forder_int | 1e+07 | threads_6 | 0.0561900 | 1.000 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_1 | 0.2831000 | 4.864 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_2 | 0.1483000 | 2.548 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_4 | 0.0804700 | 1.383 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_6 | 0.0582000 | 1.000 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_1 | 0.0019180 | 3.135 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_2 | 0.0009797 | 1.602 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_4 | 0.0006117 | 1.000 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_6 | 0.0006122 | 1.001 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_1 | 0.0227900 | 1.009 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_2 | 0.0226100 | 1.001 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_4 | 0.0226100 | 1.001 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_6 | 0.0225800 | 1.000 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_1 | 0.2119000 | 1.982 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_2 | 0.1445000 | 1.352 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_4 | 0.1202000 | 1.124 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_6 | 0.1069000 | 1.000 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_1 | 0.1913000 | 1.838 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_2 | 0.1404000 | 1.348 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_4 | 0.1144000 | 1.099 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_6 | 0.1041000 | 1.000 | TRUE |
| kit_iif | 1e+07 | threads_1 | 0.0294300 | 5.663 | TRUE |
| kit_iif | 1e+07 | threads_2 | 0.0149700 | 2.880 | TRUE |
| kit_iif | 1e+07 | threads_4 | 0.0076530 | 1.473 | TRUE |
| kit_iif | 1e+07 | threads_6 | 0.0051960 | 1.000 | TRUE |
| kit_psort_dbl | 1e+07 | threads_1 | 0.4803000 | 1.015 | TRUE |
| kit_psort_dbl | 1e+07 | threads_2 | 0.4859000 | 1.027 | TRUE |
| kit_psort_dbl | 1e+07 | threads_4 | 0.4945000 | 1.045 | TRUE |
| kit_psort_dbl | 1e+07 | threads_6 | 0.4732000 | 1.000 | TRUE |
| Rfast_colMedians | 1e+07 | threads_1 | 0.0729500 | 5.300 | TRUE |
| Rfast_colMedians | 1e+07 | threads_2 | 0.0372100 | 2.703 | TRUE |
| Rfast_colMedians | 1e+07 | threads_4 | 0.0188200 | 1.367 | TRUE |
| Rfast_colMedians | 1e+07 | threads_6 | 0.0137600 | 1.000 | TRUE |
| Rfast_colVars | 1e+07 | threads_1 | 0.0112700 | 4.446 | TRUE |
| Rfast_colVars | 1e+07 | threads_2 | 0.0058200 | 2.296 | TRUE |
| Rfast_colVars | 1e+07 | threads_4 | 0.0033940 | 1.339 | TRUE |
| Rfast_colVars | 1e+07 | threads_6 | 0.0025340 | 1.000 | TRUE |
| qs2_save_dbl | 1e+07 | threads_1 | 0.0679300 | 2.249 | TRUE |
| qs2_save_dbl | 1e+07 | threads_2 | 0.0510100 | 1.689 | TRUE |
| qs2_save_dbl | 1e+07 | threads_4 | 0.0323000 | 1.070 | TRUE |
| qs2_save_dbl | 1e+07 | threads_6 | 0.0302000 | 1.000 | TRUE |
| qs2_read_dbl | 1e+07 | threads_1 | 0.0276700 | 3.277 | TRUE |
| qs2_read_dbl | 1e+07 | threads_2 | 0.0240000 | 2.843 | TRUE |
| qs2_read_dbl | 1e+07 | threads_4 | 0.0087690 | 1.039 | TRUE |
| qs2_read_dbl | 1e+07 | threads_6 | 0.0084440 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `fastfns/b6_threads.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 64 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| DT_groupby_sum | 1e+07 | threads_1 | 0.0689900 | 2.212 | TRUE |
| DT_groupby_sum | 1e+07 | threads_2 | 0.0439100 | 1.408 | TRUE |
| DT_groupby_sum | 1e+07 | threads_4 | 0.0328000 | 1.051 | TRUE |
| DT_groupby_sum | 1e+07 | threads_8 | 0.0311900 | 1.000 | TRUE |
| DT_groupby_mean | 1e+07 | threads_1 | 0.0672100 | 2.146 | TRUE |
| DT_groupby_mean | 1e+07 | threads_2 | 0.0444800 | 1.421 | TRUE |
| DT_groupby_mean | 1e+07 | threads_4 | 0.0327100 | 1.045 | TRUE |
| DT_groupby_mean | 1e+07 | threads_8 | 0.0313100 | 1.000 | TRUE |
| DT_forder_dbl | 1e+07 | threads_1 | 0.5916000 | 1.729 | TRUE |
| DT_forder_dbl | 1e+07 | threads_2 | 0.4518000 | 1.320 | TRUE |
| DT_forder_dbl | 1e+07 | threads_4 | 0.3606000 | 1.054 | TRUE |
| DT_forder_dbl | 1e+07 | threads_8 | 0.3422000 | 1.000 | TRUE |
| DT_forder_int | 1e+07 | threads_1 | 0.2520000 | 4.624 | TRUE |
| DT_forder_int | 1e+07 | threads_2 | 0.1406000 | 2.580 | TRUE |
| DT_forder_int | 1e+07 | threads_4 | 0.0759600 | 1.394 | TRUE |
| DT_forder_int | 1e+07 | threads_8 | 0.0544900 | 1.000 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_1 | 0.2634000 | 3.238 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_2 | 0.1435000 | 1.764 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_4 | 0.0813400 | 1.000 | TRUE |
| DT_uniqueN_int | 1e+07 | threads_8 | 0.0838600 | 1.031 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_1 | 0.0023770 | 3.251 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_2 | 0.0012280 | 1.679 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_4 | 0.0007311 | 1.000 | TRUE |
| collapse_fsum_matrix_cols | 1e+07 | threads_8 | 0.0008283 | 1.133 | TRUE |
| collapse_fmean_matrix_cols | 1e+07 | threads_1 | 0.0033530 | 3.686 | TRUE |
| collapse_fmean_matrix_cols | 1e+07 | threads_2 | 0.0017170 | 1.887 | TRUE |
| collapse_fmean_matrix_cols | 1e+07 | threads_4 | 0.0009685 | 1.065 | TRUE |
| collapse_fmean_matrix_cols | 1e+07 | threads_8 | 0.0009095 | 1.000 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_1 | 0.0124800 | 1.024 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_2 | 0.0122800 | 1.007 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_4 | 0.0122400 | 1.004 | TRUE |
| collapse_fsum_grouped_vec | 1e+07 | threads_8 | 0.0121900 | 1.000 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_1 | 0.1610000 | 2.318 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_2 | 0.1085000 | 1.562 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_4 | 0.0791000 | 1.139 | TRUE |
| collapse_fmedian_grouped | 1e+07 | threads_8 | 0.0694400 | 1.000 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_1 | 0.1492000 | 2.155 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_2 | 0.1030000 | 1.488 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_4 | 0.0766000 | 1.106 | TRUE |
| collapse_fnth90_grouped | 1e+07 | threads_8 | 0.0692500 | 1.000 | TRUE |
| collapse_fmedian_matrix_cols | 1e+07 | threads_1 | 0.0762800 | 5.983 | TRUE |
| collapse_fmedian_matrix_cols | 1e+07 | threads_2 | 0.0394800 | 3.097 | TRUE |
| collapse_fmedian_matrix_cols | 1e+07 | threads_4 | 0.0204600 | 1.605 | TRUE |
| collapse_fmedian_matrix_cols | 1e+07 | threads_8 | 0.0127500 | 1.000 | TRUE |
| kit_iif | 1e+07 | threads_1 | 0.0070670 | 2.063 | TRUE |
| kit_iif | 1e+07 | threads_2 | 0.0034800 | 1.016 | TRUE |
| kit_iif | 1e+07 | threads_4 | 0.0035300 | 1.031 | TRUE |
| kit_iif | 1e+07 | threads_8 | 0.0034250 | 1.000 | TRUE |
| kit_psort_dbl | 1e+07 | threads_1 | 0.2834000 | 1.013 | TRUE |
| kit_psort_dbl | 1e+07 | threads_2 | 0.2798000 | 1.000 | TRUE |
| kit_psort_dbl | 1e+07 | threads_4 | 0.2811000 | 1.004 | TRUE |
| kit_psort_dbl | 1e+07 | threads_8 | 0.2830000 | 1.011 | TRUE |
| Rfast_colMedians | 1e+07 | threads_1 | 0.0728900 | 6.524 | TRUE |
| Rfast_colMedians | 1e+07 | threads_2 | 0.0365500 | 3.272 | TRUE |
| Rfast_colMedians | 1e+07 | threads_4 | 0.0191400 | 1.713 | TRUE |
| Rfast_colMedians | 1e+07 | threads_8 | 0.0111700 | 1.000 | TRUE |
| Rfast_colVars | 1e+07 | threads_1 | 0.0119300 | 4.554 | TRUE |
| Rfast_colVars | 1e+07 | threads_2 | 0.0062500 | 2.385 | TRUE |
| Rfast_colVars | 1e+07 | threads_4 | 0.0033220 | 1.268 | TRUE |
| Rfast_colVars | 1e+07 | threads_8 | 0.0026200 | 1.000 | TRUE |
| Rfast_colsums | 1e+07 | threads_1 | 0.0037180 | 4.522 | TRUE |
| Rfast_colsums | 1e+07 | threads_2 | 0.0019090 | 2.322 | TRUE |
| Rfast_colsums | 1e+07 | threads_4 | 0.0010350 | 1.259 | TRUE |
| Rfast_colsums | 1e+07 | threads_8 | 0.0008222 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `remote/b12.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 9 rows
</summary>

| task          | n   | method                         | seconds | mb_fetched |
|:--------------|:----|:-------------------------------|--------:|-----------:|
| b1_projection | NA  | 3 cols, filter DepDelay\>300   |   2.916 |     10.930 |
| b1_projection | NA  | 20 cols, filter DepDelay\>300  |   2.524 |     43.930 |
| b1_projection | NA  | all cols, filter DepDelay\>300 |  29.580 |    190.900 |
| b1_projection | NA  | count(\*) only (footer)        |   1.316 |      1.265 |
| b2_pruning    | NA  | 2 urls, Year = 2024 (hive)     |   2.981 |     12.390 |
| b2_pruning    | NA  | 2 urls, no Year filter         |   5.410 |     97.010 |
| b2_rowgroup   | NA  | filter FlightDate = one day    |   1.721 |      2.957 |
| b2_rowgroup   | NA  | filter Origin = 'JFK'          |   2.160 |     10.930 |
| b2_rowgroup   | NA  | no filter, 3 cols (count)      |   2.079 |      8.359 |

</details>

<details>

<summary>

Source: benchmark results `remote/b3.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 15 rows
</summary>

| task | n | method | seconds | mb_fetched |
|:---|:---|:---|---:|---:|
| b3a_ext_cache | NA | cache=TRUE run1 (cold) | 1.711 | 10.600 |
| b3a_ext_cache | NA | cache=TRUE run2 same query | 0.368 | 0.000 |
| b3a_ext_cache | NA | cache=TRUE run3 other cols | 0.673 | 7.465 |
| b3a_ext_cache | NA | cache=FALSE run1 (cold) | 2.341 | 10.930 |
| b3a_ext_cache | NA | cache=FALSE run2 same query | 1.913 | 10.930 |
| b3a_ext_cache | NA | cache=FALSE run3 other cols | 1.888 | 18.200 |
| b3b_meta_cache | NA | off run1 | 2.110 | 10.930 |
| b3b_meta_cache | NA | off run2 other cols | 1.716 | 18.200 |
| b3b_meta_cache | NA | http_meta on run1 | 2.052 | 10.930 |
| b3b_meta_cache | NA | http_meta on run2 other cols | 1.446 | 18.200 |
| b3b_meta_cache | NA | http_meta + parquet_meta on run1 | 2.154 | 10.300 |
| b3b_meta_cache | NA | http_meta + parquet_meta on run2 other cols | 0.891 | 16.940 |
| b3c_cache_httpfs | NA | session 1 (cold) | 2.659 | 82.750 |
| b3c_cache_httpfs | NA | session 2 (warm, fresh R) | 0.660 | 0.000 |
| b3c_cache_httpfs | NA | session 3 (warm, fresh R) | 0.623 | 0.000 |

</details>

<details>

<summary>

Source: benchmark results `remote/b4.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 8 rows
</summary>

| task        | n   | method                            | seconds | mb_fetched |
|:------------|:----|:----------------------------------|--------:|-----------:|
| b4_download | NA  | curl::multi_download              |   3.327 |         NA |
| b4_download | NA  | aria2c -x4 -s4                    |   1.233 |         NA |
| b4_query    | NA  | remote range-read, 3 cols         |   2.490 |      10.93 |
| b4_query    | NA  | local file, 3 cols                |   0.048 |         NA |
| b4_query    | NA  | remote range-read, 20 cols        |   2.449 |      43.93 |
| b4_query    | NA  | local file, 20 cols               |   0.154 |         NA |
| b4_query    | NA  | remote range-read, all cols (110) |  22.390 |     190.90 |
| b4_query    | NA  | local file, all cols (110)        |   0.811 |         NA |

</details>

<details>

<summary>

Source: benchmark results `remote/b5.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 8 rows
</summary>

| task | n | method | seconds | mb_fetched |
|:---|:---|:---|---:|:---|
| b5_frontend | NA | duckplyr read_parquet_duckdb run1 cold | 1.702 | NA |
| b5_frontend | NA | duckplyr read_parquet_duckdb run2 same session | 0.197 | NA |
| b5_frontend | NA | dbplyr tbl(sql read_parquet) run1 cold | 2.354 | NA |
| b5_frontend | NA | dbplyr tbl(sql read_parquet) run2 same session | 0.687 | NA |
| b5_frontend | NA | dbplyr tbl(I(url)) run1 cold | NA | NA |
| b5_frontend | NA | arrow open_dataset(https) run1 cold | NA | NA |
| b5_frontend | NA | arrow read_parquet(https) run1 cold | 3.762 | NA |
| b5_frontend | NA | arrow read_parquet(https) run2 same session | 4.096 | NA |

</details>

<details>

<summary>

Source: benchmark results `remote/b67.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 9 rows
</summary>

| task | n | method | seconds | mb_fetched |
|:---|:---|:---|---:|---:|
| b6_conn_reuse | NA | new connection + INSTALL/LOAD httpfs + secret, SELECT 1 | 0.355 | NA |
| b6_conn_reuse | NA | memoized connection, SELECT 1 | 0.024 | NA |
| b6_conn_reuse | NA | new connection each call, remote count(\*) | 19.150 | NA |
| b6_conn_reuse | NA | memoized connection, remote count(\*) | 6.885 | NA |
| b7_defaults | NA | default threads/memory_limit | NA | NA |
| b7_threads_remote | NA | threads 1 | 4.042 | 47.34 |
| b7_threads_remote | NA | threads 2 | 3.201 | 45.50 |
| b7_threads_remote | NA | threads 4 | 2.824 | 40.12 |
| b7_threads_remote | NA | threads 12 | 2.184 | 10.93 |

</details>

<details>

<summary>

Source: benchmark results `remote/ordering_store_size.csv` (run 2026-11-03) 5 rows
</summary>

| object | rows | cols | ram_mb | qs2_mb | parquet_mb | as_of | notes |
|:---|---:|---:|---:|---:|---:|:---|:---|
| full | 2000000 | 6 | 224.1000 | 45.8800 | 68.5800 | 2026-11-03 | synthetic 2e6-row table; qs2 nthreads=1 default level; nanoparquet default |
| 3 cols | 2000000 | 3 | 30.5200 | 13.1600 | 23.2200 | 2026-11-03 | synthetic 2e6-row table; qs2 nthreads=1 default level; nanoparquet default |
| filtered 5% rows, all cols | 100100 | 6 | 12.6100 | 2.5070 | 3.3880 | 2026-11-03 | synthetic 2e6-row table; qs2 nthreads=1 default level; nanoparquet default |
| filtered 5% + 3 cols | 100100 | 3 | 1.9100 | 0.9210 | 1.1190 | 2026-11-03 | synthetic 2e6-row table; qs2 nthreads=1 default level; nanoparquet default |
| filtered 1% + 3 cols | 20040 | 3 | 0.3831 | 0.1754 | 0.2184 | 2026-11-03 | synthetic 2e6-row table; qs2 nthreads=1 default level; nanoparquet default |

</details>

<details>

<summary>

Source: benchmark results `remote/ordering.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 49 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| a1_mutate_filter | 2e+06 | dplyr_bad | 0.740 | 67.270 | TRUE |
| a1_mutate_filter | 2e+06 | dplyr_good | 0.049 | 4.455 | TRUE |
| a1_mutate_filter | 2e+06 | dt_bad | 0.751 | 68.270 | TRUE |
| a1_mutate_filter | 2e+06 | dt_good | 0.047 | 4.273 | TRUE |
| a1_mutate_filter | 2e+06 | duckplyr_bad | 0.013 | 1.182 | TRUE |
| a1_mutate_filter | 2e+06 | duckplyr_good | 0.011 | 1.000 | TRUE |
| a1_mutate_filter | 2e+06 | dbplyr_bad | 0.067 | 6.091 | TRUE |
| a1_mutate_filter | 2e+06 | dbplyr_good | 0.068 | 6.182 | TRUE |
| a2a_join_filter_fact | 2e+06 | dplyr_bad | 0.066 | 13.200 | TRUE |
| a2a_join_filter_fact | 2e+06 | dplyr_good | 0.008 | 1.600 | TRUE |
| a2a_join_filter_fact | 2e+06 | dt_bad | 0.093 | 18.600 | TRUE |
| a2a_join_filter_fact | 2e+06 | dt_good | 0.005 | 1.000 | TRUE |
| a2a_join_filter_fact | 2e+06 | duckplyr_bad | 0.008 | 1.600 | TRUE |
| a2a_join_filter_fact | 2e+06 | duckplyr_good | 0.008 | 1.600 | TRUE |
| a2a_join_filter_fact | 2e+06 | dbplyr_bad | 0.026 | 5.200 | TRUE |
| a2a_join_filter_fact | 2e+06 | dbplyr_good | 0.028 | 5.600 | TRUE |
| a2b_join_filter_dim | 2e+06 | dplyr_bad | 0.069 | 9.857 | TRUE |
| a2b_join_filter_dim | 2e+06 | dplyr_good | 0.021 | 3.000 | TRUE |
| a2b_join_filter_dim | 2e+06 | dplyr_semi | 0.020 | 2.857 | TRUE |
| a2b_join_filter_dim | 2e+06 | dt_bad | 0.093 | 13.290 | TRUE |
| a2b_join_filter_dim | 2e+06 | dt_good | 0.012 | 1.714 | TRUE |
| a2b_join_filter_dim | 2e+06 | duckplyr_bad | 0.008 | 1.143 | TRUE |
| a2b_join_filter_dim | 2e+06 | duckplyr_good | 0.007 | 1.000 | TRUE |
| a2b_join_filter_dim | 2e+06 | dbplyr_bad | 0.027 | 3.857 | TRUE |
| a2b_join_filter_dim | 2e+06 | dbplyr_good | 0.029 | 4.143 | TRUE |
| a2c_join_agg | 2e+06 | dplyr_bad | 0.092 | 10.220 | TRUE |
| a2c_join_agg | 2e+06 | dplyr_good | 0.023 | 2.556 | TRUE |
| a2c_join_agg | 2e+06 | dt_bad | 0.100 | 11.110 | TRUE |
| a2c_join_agg | 2e+06 | dt_good | 0.009 | 1.000 | TRUE |
| a2c_join_agg | 2e+06 | duckplyr_bad | 0.012 | 1.333 | TRUE |
| a2c_join_agg | 2e+06 | duckplyr_good | 0.009 | 1.000 | TRUE |
| a2c_join_agg | 2e+06 | dbplyr_bad | 0.023 | 2.556 | TRUE |
| a2c_join_agg | 2e+06 | dbplyr_good | 0.022 | 2.444 | TRUE |
| a3a_arrange_early | 2e+06 | dplyr_bad | 0.179 | 11.190 | TRUE |
| a3a_arrange_early | 2e+06 | dplyr_good | 0.055 | 3.437 | TRUE |
| a3a_arrange_early | 2e+06 | dt_bad | 0.133 | 8.312 | TRUE |
| a3a_arrange_early | 2e+06 | dt_good | 0.048 | 3.000 | TRUE |
| a3a_arrange_early | 2e+06 | duckplyr_bad | 0.032 | 2.000 | TRUE |
| a3a_arrange_early | 2e+06 | duckplyr_good | 0.016 | 1.000 | TRUE |
| a3a_arrange_early | 2e+06 | dbplyr_bad | 0.027 | 1.687 | TRUE |
| a3a_arrange_early | 2e+06 | dbplyr_good | 0.026 | 1.625 | TRUE |
| a3b_distinct_first | 2e+06 | dplyr_bad | 0.360 | 30.000 | TRUE |
| a3b_distinct_first | 2e+06 | dplyr_good | 0.012 | 1.000 | TRUE |
| a3b_distinct_first | 2e+06 | dt_bad | 0.365 | 30.420 | TRUE |
| a3b_distinct_first | 2e+06 | dt_good | 0.025 | 2.083 | TRUE |
| a3b_distinct_first | 2e+06 | duckplyr_bad | 0.045 | 3.750 | TRUE |
| a3b_distinct_first | 2e+06 | duckplyr_good | 0.013 | 1.083 | TRUE |
| a3b_distinct_first | 2e+06 | dbplyr_bad | 0.058 | 4.833 | TRUE |
| a3b_distinct_first | 2e+06 | dbplyr_good | 0.026 | 2.167 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `startup/oversubscribe.csv` (run 2026-11-03) 3 rows
</summary>

| setting            |  wall | threads | workers | ncpu | date       |
|:-------------------|------:|--------:|--------:|-----:|:-----------|
| default (50% each) | 2.078 |       6 |       6 |   12 | 2026-11-03 |
| 1 thread each      | 1.548 |       1 |       6 |   12 | 2026-11-03 |
| all cpus each      | 9.458 |      12 |       6 |   12 | 2026-11-03 |

</details>

<details>

<summary>

Source: benchmark results `startup/pkg_load_time.csv` (R 4.6.2; run 2026-11-03) 11 rows
</summary>

| pkg        | attach_s | namespace_s | attach2_s | bare_rscript_s | r_version | date       |
|:-----------|---------:|------------:|----------:|---------------:|:----------|:-----------|
| targets    |    0.252 |       0.252 |     0.245 |          0.144 | 4.6.2     | 2026-11-03 |
| crew       |    0.231 |       0.226 |     0.224 |          0.144 | 4.6.2     | 2026-11-03 |
| dplyr      |    0.145 |       0.153 |     0.150 |          0.144 | 4.6.2     | 2026-11-03 |
| tidyverse  |       NA |          NA |        NA |          0.144 | 4.6.2     | 2026-11-03 |
| ggplot2    |       NA |          NA |        NA |          0.144 | 4.6.2     | 2026-11-03 |
| arrow      |    0.171 |       0.153 |     0.171 |          0.144 | 4.6.2     | 2026-11-03 |
| duckdb     |    0.193 |       0.158 |     0.161 |          0.144 | 4.6.2     | 2026-11-03 |
| sf         |       NA |          NA |        NA |          0.144 | 4.6.2     | 2026-11-03 |
| data.table |    0.028 |       0.026 |     0.029 |          0.144 | 4.6.2     | 2026-11-03 |
| collapse   |    0.054 |       0.049 |     0.055 |          0.144 | 4.6.2     | 2026-11-03 |
| qs2        |    0.049 |       0.061 |     0.054 |          0.144 | 4.6.2     | 2026-11-03 |

</details>

<details>

<summary>

Source: benchmark results `storage/fidelity.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 70 rows
</summary>

| task                       |   n | method      | status    |
|:---------------------------|----:|:------------|:----------|
| fidelity_df_rownames_attrs |   1 | rds         | identical |
| fidelity_df_rownames_attrs |   1 | qs2         | identical |
| fidelity_df_rownames_attrs |   1 | qd          | identical |
| fidelity_df_rownames_attrs |   1 | zap         | identical |
| fidelity_df_rownames_attrs |   1 | nanoparquet | lossy     |
| fidelity_df_rownames_attrs |   1 | arrow       | lossy     |
| fidelity_df_rownames_attrs |   1 | duckdb      | lossy     |
| fidelity_tibble            |   1 | rds         | identical |
| fidelity_tibble            |   1 | qs2         | identical |
| fidelity_tibble            |   1 | qd          | identical |
| fidelity_tibble            |   1 | zap         | identical |
| fidelity_tibble            |   1 | nanoparquet | lossy     |
| fidelity_tibble            |   1 | arrow       | identical |
| fidelity_tibble            |   1 | duckdb      | lossy     |
| fidelity_list_col          |   1 | rds         | identical |
| fidelity_list_col          |   1 | qs2         | identical |
| fidelity_list_col          |   1 | qd          | identical |
| fidelity_list_col          |   1 | zap         | identical |
| fidelity_list_col          |   1 | nanoparquet | ERROR     |
| fidelity_list_col          |   1 | arrow       | ERROR     |
| fidelity_list_col          |   1 | duckdb      | ERROR     |
| fidelity_grouped_df        |   1 | rds         | identical |
| fidelity_grouped_df        |   1 | qs2         | identical |
| fidelity_grouped_df        |   1 | qd          | identical |
| fidelity_grouped_df        |   1 | zap         | identical |
| fidelity_grouped_df        |   1 | nanoparquet | lossy     |
| fidelity_grouped_df        |   1 | arrow       | identical |
| fidelity_grouped_df        |   1 | duckdb      | lossy     |
| fidelity_difftime_cplx_raw |   1 | rds         | identical |
| fidelity_difftime_cplx_raw |   1 | qs2         | identical |
| fidelity_difftime_cplx_raw |   1 | qd          | identical |
| fidelity_difftime_cplx_raw |   1 | zap         | identical |
| fidelity_difftime_cplx_raw |   1 | nanoparquet | ERROR     |
| fidelity_difftime_cplx_raw |   1 | arrow       | ERROR     |
| fidelity_difftime_cplx_raw |   1 | duckdb      | ERROR     |
| fidelity_named_list        |   1 | rds         | identical |
| fidelity_named_list        |   1 | qs2         | identical |
| fidelity_named_list        |   1 | qd          | identical |
| fidelity_named_list        |   1 | zap         | identical |
| fidelity_named_list        |   1 | nanoparquet | ERROR     |
| fidelity_named_list        |   1 | arrow       | ERROR     |
| fidelity_named_list        |   1 | duckdb      | lossy     |
| fidelity_s4_object         |   1 | rds         | identical |
| fidelity_s4_object         |   1 | qs2         | identical |
| fidelity_s4_object         |   1 | qd          | lossy     |
| fidelity_s4_object         |   1 | zap         | identical |
| fidelity_s4_object         |   1 | nanoparquet | ERROR     |
| fidelity_s4_object         |   1 | arrow       | ERROR     |
| fidelity_s4_object         |   1 | duckdb      | ERROR     |
| fidelity_formula           |   1 | rds         | identical |
| fidelity_formula           |   1 | qs2         | identical |
| fidelity_formula           |   1 | qd          | lossy     |
| fidelity_formula           |   1 | zap         | identical |
| fidelity_formula           |   1 | nanoparquet | ERROR     |
| fidelity_formula           |   1 | arrow       | ERROR     |
| fidelity_formula           |   1 | duckdb      | ERROR     |
| fidelity_closure           |   1 | rds         | identical |
| fidelity_closure           |   1 | qs2         | identical |
| fidelity_closure           |   1 | qd          | lossy     |
| fidelity_closure           |   1 | zap         | identical |
| fidelity_closure           |   1 | nanoparquet | ERROR     |
| fidelity_closure           |   1 | arrow       | ERROR     |
| fidelity_closure           |   1 | duckdb      | ERROR     |
| fidelity_environment       |   1 | rds         | lossy     |
| fidelity_environment       |   1 | qs2         | lossy     |
| fidelity_environment       |   1 | qd          | lossy     |
| fidelity_environment       |   1 | zap         | lossy     |
| fidelity_environment       |   1 | nanoparquet | ERROR     |
| fidelity_environment       |   1 | arrow       | ERROR     |
| fidelity_environment       |   1 | duckdb      | ERROR     |

</details>

<details>

<summary>

Source: benchmark results `storage/storage_rss.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 32 rows
</summary>

| task | n | method | peak_rss_mb | net_rss_mb |
|:---|---:|:---|---:|---:|
| a_peak_rss_read | 2500000 | qs2_full@full.qs2 | 404.4 | 234.800 |
| a_peak_rss_read | 2500000 | qs2_full_cols@full.qs2 | 404.3 | 234.800 |
| a_peak_rss_read | 2500000 | qs2_full_cols_1t@full.qs2 | 303.9 | 134.300 |
| a_peak_rss_read | 2500000 | np_full@rg122880_unsorted.parquet | 382.8 | 213.200 |
| a_peak_rss_read | 2500000 | np_cols@rg122880_unsorted.parquet | 208.0 | 38.380 |
| a_peak_rss_read | 2500000 | arrow_full@rg122880_unsorted.parquet | 559.9 | 390.300 |
| a_peak_rss_read | 2500000 | arrow_cols@rg122880_unsorted.parquet | 267.2 | 97.610 |
| a_peak_rss_read | 2500000 | duck_cols@rg122880_unsorted.parquet | 289.1 | 119.500 |
| a_peak_rss_read | 2500000 | duck_cols_1t@rg122880_unsorted.parquet | 252.5 | 82.920 |
| a_peak_rss_read | 2500000 | arrow_cols_1t@rg122880_unsorted.parquet | 262.5 | 92.920 |
| a_peak_rss_read | 2500000 | arrow_filter@rg122880_unsorted.parquet | 439.6 | 270.000 |
| a_peak_rss_read | 2500000 | duck_filter@rg122880_unsorted.parquet | 431.6 | 262.000 |
| a_peak_rss_read | 2500000 | arrow_filter@rg122880_sorted.parquet | 200.7 | 31.110 |
| a_peak_rss_read | 2500000 | duck_filter@rg122880_sorted.parquet | 205.2 | 35.660 |
| a_peak_rss_read | 2500000 | np_full_filter@rg122880_sorted.parquet | 391.1 | 221.500 |
| a_peak_rss_read | 2500000 | qs2_full_filter@full.qs2 | 414.3 | 244.700 |
| b_peak_rss_read | 150000 | qs2_full@full.qs2 | 319.5 | 149.900 |
| b_peak_rss_read | 150000 | qs2_full_cols@full.qs2 | 320.2 | 150.600 |
| b_peak_rss_read | 150000 | qs2_full_cols_1t@full.qs2 | 203.9 | 34.270 |
| b_peak_rss_read | 150000 | np_full@rg122880_unsorted.parquet | 324.7 | 155.100 |
| b_peak_rss_read | 150000 | np_cols@rg122880_unsorted.parquet | 174.3 | 4.703 |
| b_peak_rss_read | 150000 | arrow_full@rg122880_unsorted.parquet | 715.6 | 546.000 |
| b_peak_rss_read | 150000 | arrow_cols@rg122880_unsorted.parquet | 176.8 | 7.172 |
| b_peak_rss_read | 150000 | duck_cols@rg122880_unsorted.parquet | 190.8 | 21.170 |
| b_peak_rss_read | 150000 | duck_cols_1t@rg122880_unsorted.parquet | 191.2 | 21.590 |
| b_peak_rss_read | 150000 | arrow_cols_1t@rg122880_unsorted.parquet | 175.6 | 6.031 |
| b_peak_rss_read | 150000 | arrow_filter@rg122880_unsorted.parquet | 602.0 | 432.400 |
| b_peak_rss_read | 150000 | duck_filter@rg122880_unsorted.parquet | 247.5 | 77.920 |
| b_peak_rss_read | 150000 | arrow_filter@rg122880_sorted.parquet | 540.9 | 371.300 |
| b_peak_rss_read | 150000 | duck_filter@rg122880_sorted.parquet | 222.6 | 52.970 |
| b_peak_rss_read | 150000 | np_full_filter@rg122880_sorted.parquet | 324.7 | 155.100 |
| b_peak_rss_read | 150000 | qs2_full_filter@full.qs2 | 324.0 | 154.400 |

</details>

<details>

<summary>

Source: benchmark results `storage/storage.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-02, 2026-11-03) 259 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | file_mb | identical_to_ref |
|:---|---:|:---|---:|---:|---:|:---|
| a_numdf_write | 1.0e+07 | rds_gzip | 2.408e+01 | 90.860 | 407.70 | TRUE |
| a_numdf_write | 1.0e+07 | rds_none | 4.333e-01 | 1.635 | 534.10 | TRUE |
| a_numdf_write | 1.0e+07 | qs2_t1 | 1.228e+00 | 4.636 | 375.80 | TRUE |
| a_numdf_write | 1.0e+07 | qs2_t4 | 3.953e-01 | 1.492 | 375.80 | TRUE |
| a_numdf_write | 1.0e+07 | qs2_t1_l1 | 8.164e-01 | 3.081 | 386.10 | TRUE |
| a_numdf_write | 1.0e+07 | qs2_t4_l1 | 2.650e-01 | 1.000 | 386.10 | TRUE |
| a_numdf_write | 1.0e+07 | qd_t1 | 1.241e+00 | 4.684 | 376.00 | TRUE |
| a_numdf_write | 1.0e+07 | qd_t4 | 4.001e-01 | 1.510 | 376.00 | TRUE |
| a_numdf_write | 1.0e+07 | zap | 7.702e-01 | 2.907 | 362.40 | TRUE |
| a_numdf_write | 1.0e+07 | np_snappy | 1.494e+00 | 5.639 | 487.90 | FALSE |
| a_numdf_write | 1.0e+07 | np_zstd | 1.238e+00 | 4.671 | 509.20 | FALSE |
| a_numdf_write | 1.0e+07 | arrow_snappy | 1.316e+00 | 4.968 | 516.70 | FALSE |
| a_numdf_write | 1.0e+07 | arrow_zstd | 1.555e+00 | 5.868 | 462.90 | FALSE |
| a_numdf_write | 1.0e+07 | duck_zstd | 1.929e+00 | 7.282 | 425.30 | TRUE |
| a_numdf_read | 1.0e+07 | rds_gzip | 1.286e+00 | 8.872 | 407.70 | TRUE |
| a_numdf_read | 1.0e+07 | rds_none | 3.622e-01 | 2.498 | 534.10 | TRUE |
| a_numdf_read | 1.0e+07 | qs2_t1 | 4.365e-01 | 3.011 | 375.80 | TRUE |
| a_numdf_read | 1.0e+07 | qs2_t4 | 1.566e-01 | 1.080 | 375.80 | TRUE |
| a_numdf_read | 1.0e+07 | qs2_t1_l1 | 3.559e-01 | 2.455 | 386.10 | TRUE |
| a_numdf_read | 1.0e+07 | qs2_t4_l1 | 1.449e-01 | 1.000 | 386.10 | TRUE |
| a_numdf_read | 1.0e+07 | qd_t1 | 4.329e-01 | 2.986 | 376.00 | TRUE |
| a_numdf_read | 1.0e+07 | qd_t4 | 1.610e-01 | 1.111 | 376.00 | TRUE |
| a_numdf_read | 1.0e+07 | zap | 5.474e-01 | 3.777 | 362.40 | TRUE |
| a_numdf_read | 1.0e+07 | np_snappy | 3.580e-01 | 2.470 | 487.90 | FALSE |
| a_numdf_read | 1.0e+07 | np_zstd | 2.830e-01 | 1.952 | 509.20 | FALSE |
| a_numdf_read | 1.0e+07 | arrow_snappy | 1.989e-01 | 1.373 | 516.70 | FALSE |
| a_numdf_read | 1.0e+07 | arrow_zstd | 1.946e-01 | 1.342 | 462.90 | FALSE |
| a_numdf_read | 1.0e+07 | duck_zstd | 8.228e-01 | 5.676 | 425.30 | TRUE |
| a_numdf_write | 1.0e+07 | fst | NA | NA | NA | NA |
| a_numdf_write | 1.0e+07 | fst_c0 | NA | NA | NA | NA |
| b_chartbl_write | 1.0e+06 | rds_gzip | 1.911e+01 | 25.800 | 292.40 | TRUE |
| b_chartbl_write | 1.0e+06 | rds_none | 8.033e-01 | 1.085 | 879.00 | TRUE |
| b_chartbl_write | 1.0e+06 | qs2_t1 | 3.200e+00 | 4.320 | 251.00 | TRUE |
| b_chartbl_write | 1.0e+06 | qs2_t4 | 9.001e-01 | 1.215 | 251.00 | TRUE |
| b_chartbl_write | 1.0e+06 | qs2_t1_l1 | 2.558e+00 | 3.453 | 280.80 | TRUE |
| b_chartbl_write | 1.0e+06 | qs2_t4_l1 | 7.407e-01 | 1.000 | 280.80 | TRUE |
| b_chartbl_write | 1.0e+06 | qd_t1 | 3.152e+00 | 4.256 | 249.60 | TRUE |
| b_chartbl_write | 1.0e+06 | qd_t4 | 8.675e-01 | 1.171 | 249.60 | TRUE |
| b_chartbl_write | 1.0e+06 | qd_t1_noalt | 3.164e+00 | 4.271 | 249.60 | TRUE |
| b_chartbl_write | 1.0e+06 | zap | 2.892e+00 | 3.904 | 225.10 | TRUE |
| b_chartbl_write | 1.0e+06 | np_snappy | 2.270e+00 | 3.065 | 430.00 | FALSE |
| b_chartbl_write | 1.0e+06 | np_zstd | 8.531e-01 | 1.152 | 865.80 | FALSE |
| b_chartbl_write | 1.0e+06 | arrow_snappy | 2.525e+00 | 3.409 | 425.10 | TRUE |
| b_chartbl_write | 1.0e+06 | arrow_zstd | 3.420e+00 | 4.618 | 282.00 | TRUE |
| b_chartbl_write | 1.0e+06 | duck_zstd | 1.221e+00 | 1.648 | 56.33 | FALSE |
| b_chartbl_read | 1.0e+06 | rds_gzip | 3.202e+00 | 6.103 | 292.40 | TRUE |
| b_chartbl_read | 1.0e+06 | rds_none | 1.441e+00 | 2.747 | 879.00 | TRUE |
| b_chartbl_read | 1.0e+06 | qs2_t1 | 1.858e+00 | 3.541 | 251.00 | TRUE |
| b_chartbl_read | 1.0e+06 | qs2_t4 | 1.127e+00 | 2.147 | 251.00 | TRUE |
| b_chartbl_read | 1.0e+06 | qs2_t1_l1 | 1.785e+00 | 3.402 | 280.80 | TRUE |
| b_chartbl_read | 1.0e+06 | qs2_t4_l1 | 1.115e+00 | 2.125 | 280.80 | TRUE |
| b_chartbl_read | 1.0e+06 | qd_t1 | 1.773e+00 | 3.380 | 249.60 | TRUE |
| b_chartbl_read | 1.0e+06 | qd_t4 | 1.038e+00 | 1.979 | 249.60 | TRUE |
| b_chartbl_read | 1.0e+06 | qd_t1_noalt | 1.879e+00 | 3.582 | 249.60 | TRUE |
| b_chartbl_read | 1.0e+06 | zap | 1.982e+00 | 3.778 | 225.10 | TRUE |
| b_chartbl_read | 1.0e+06 | np_snappy | 1.589e+00 | 3.029 | 430.00 | FALSE |
| b_chartbl_read | 1.0e+06 | np_zstd | 1.367e+00 | 2.606 | 865.80 | FALSE |
| b_chartbl_read | 1.0e+06 | arrow_snappy | 5.247e-01 | 1.000 | 425.10 | TRUE |
| b_chartbl_read | 1.0e+06 | arrow_zstd | 9.617e-01 | 1.833 | 282.00 | TRUE |
| b_chartbl_read | 1.0e+06 | duck_zstd | 1.566e+00 | 2.985 | 56.33 | FALSE |
| b_chartbl_write | 1.0e+06 | fst | NA | NA | NA | NA |
| b_chartbl_write | 1.0e+06 | fst_c0 | NA | NA | NA | NA |
| c_listdf_write | 1.0e+05 | rds_gzip | 9.649e-01 | 12.530 | 11.29 | TRUE |
| c_listdf_write | 1.0e+05 | rds_none | 2.469e-01 | 3.206 | 33.09 | TRUE |
| c_listdf_write | 1.0e+05 | qs2_t1 | 1.532e-01 | 1.989 | 10.38 | TRUE |
| c_listdf_write | 1.0e+05 | qs2_t4 | 9.194e-02 | 1.194 | 10.38 | TRUE |
| c_listdf_write | 1.0e+05 | qs2_t1_l1 | 1.410e-01 | 1.831 | 10.52 | TRUE |
| c_listdf_write | 1.0e+05 | qs2_t4_l1 | 1.035e-01 | 1.344 | 10.52 | TRUE |
| c_listdf_write | 1.0e+05 | qd_t1 | 1.330e-01 | 1.728 | 8.95 | TRUE |
| c_listdf_write | 1.0e+05 | qd_t4 | 7.701e-02 | 1.000 | 8.95 | TRUE |
| c_listdf_write | 1.0e+05 | zap | 5.454e-01 | 7.082 | 10.08 | TRUE |
| c_listdf_read | 1.0e+05 | rds_gzip | 3.671e-01 | 4.605 | 11.29 | TRUE |
| c_listdf_read | 1.0e+05 | rds_none | 5.016e-01 | 6.291 | 33.09 | TRUE |
| c_listdf_read | 1.0e+05 | qs2_t1 | 1.014e-01 | 1.272 | 10.38 | TRUE |
| c_listdf_read | 1.0e+05 | qs2_t4 | 3.499e-01 | 4.389 | 10.38 | TRUE |
| c_listdf_read | 1.0e+05 | qs2_t1_l1 | 1.022e-01 | 1.282 | 10.52 | TRUE |
| c_listdf_read | 1.0e+05 | qs2_t4_l1 | 2.776e-01 | 3.482 | 10.52 | TRUE |
| c_listdf_read | 1.0e+05 | qd_t1 | 1.247e-01 | 1.564 | 8.95 | TRUE |
| c_listdf_read | 1.0e+05 | qd_t4 | 7.973e-02 | 1.000 | 8.95 | TRUE |
| c_listdf_read | 1.0e+05 | zap | 4.508e-01 | 5.655 | 10.08 | TRUE |
| c_listcol_write | 1.0e+05 | rds_gzip | 9.951e-01 | 12.500 | 11.29 | TRUE |
| c_listcol_write | 1.0e+05 | rds_none | 2.850e-01 | 3.580 | 33.09 | TRUE |
| c_listcol_write | 1.0e+05 | qs2_t1 | 1.746e-01 | 2.194 | 10.38 | TRUE |
| c_listcol_write | 1.0e+05 | qs2_t4 | 8.997e-02 | 1.130 | 10.38 | TRUE |
| c_listcol_write | 1.0e+05 | qs2_t1_l1 | 1.461e-01 | 1.835 | 10.52 | TRUE |
| c_listcol_write | 1.0e+05 | qs2_t4_l1 | 8.773e-02 | 1.102 | 10.52 | TRUE |
| c_listcol_write | 1.0e+05 | qd_t1 | 1.166e-01 | 1.464 | 9.20 | TRUE |
| c_listcol_write | 1.0e+05 | qd_t4 | 7.960e-02 | 1.000 | 9.20 | TRUE |
| c_listcol_write | 1.0e+05 | zap | 5.812e-01 | 7.301 | 10.08 | TRUE |
| c_listcol_write | 1.0e+05 | arrow_zstd | 1.973e-01 | 2.479 | 9.44 | FALSE |
| c_listcol_write | 1.0e+05 | duck_zstd | 1.473e+00 | 18.500 | 8.99 | FALSE |
| c_listcol_read | 1.0e+05 | rds_gzip | 5.090e-01 | 4.654 | 11.29 | TRUE |
| c_listcol_read | 1.0e+05 | rds_none | 6.244e-01 | 5.708 | 33.09 | TRUE |
| c_listcol_read | 1.0e+05 | qs2_t1 | 1.518e-01 | 1.388 | 10.38 | TRUE |
| c_listcol_read | 1.0e+05 | qs2_t4 | 3.984e-01 | 3.643 | 10.38 | TRUE |
| c_listcol_read | 1.0e+05 | qs2_t1_l1 | 1.334e-01 | 1.219 | 10.52 | TRUE |
| c_listcol_read | 1.0e+05 | qs2_t4_l1 | 1.094e-01 | 1.000 | 10.52 | TRUE |
| c_listcol_read | 1.0e+05 | qd_t1 | 1.201e-01 | 1.098 | 9.20 | TRUE |
| c_listcol_read | 1.0e+05 | qd_t4 | 1.535e-01 | 1.404 | 9.20 | TRUE |
| c_listcol_read | 1.0e+05 | zap | 7.703e-01 | 7.042 | 10.08 | TRUE |
| c_listcol_read | 1.0e+05 | arrow_zstd | 2.951e+00 | 26.970 | 9.44 | FALSE |
| c_listcol_read | 1.0e+05 | duck_zstd | 1.581e+00 | 14.450 | 8.99 | FALSE |
| c_listcol_write | 1.0e+05 | np_zstd | NA | NA | NA | NA |
| c_listcol_write | 1.0e+05 | fst | NA | NA | NA | NA |
| d_matrix_write | 2.5e+07 | rds_gzip | 5.367e+00 | 40.600 | 183.10 | TRUE |
| d_matrix_write | 2.5e+07 | rds_none | 1.668e-01 | 1.262 | 190.70 | TRUE |
| d_matrix_write | 2.5e+07 | qs2_t1 | 2.242e-01 | 1.696 | 168.10 | TRUE |
| d_matrix_write | 2.5e+07 | qs2_t4 | 1.357e-01 | 1.026 | 168.10 | TRUE |
| d_matrix_write | 2.5e+07 | qs2_t1_l1 | 2.746e-01 | 2.078 | 168.20 | TRUE |
| d_matrix_write | 2.5e+07 | qs2_t4_l1 | 1.500e-01 | 1.135 | 168.20 | TRUE |
| d_matrix_write | 2.5e+07 | qd_t1 | 3.511e-01 | 2.656 | 168.10 | TRUE |
| d_matrix_write | 2.5e+07 | qd_t4 | 1.322e-01 | 1.000 | 168.10 | TRUE |
| d_matrix_write | 2.5e+07 | zap | 6.664e-01 | 5.042 | 170.00 | TRUE |
| d_matrix_write | 2.5e+07 | np_zstd_df | 1.966e+00 | 14.870 | 191.50 | FALSE |
| d_matrix_write | 2.5e+07 | arrow_zstd_df | 1.216e+00 | 9.203 | 222.40 | FALSE |
| d_matrix_read | 2.5e+07 | rds_gzip | 1.130e+00 | 15.030 | 183.10 | TRUE |
| d_matrix_read | 2.5e+07 | rds_none | 2.128e-01 | 2.831 | 190.70 | TRUE |
| d_matrix_read | 2.5e+07 | qs2_t1 | 1.399e-01 | 1.861 | 168.10 | TRUE |
| d_matrix_read | 2.5e+07 | qs2_t4 | 7.564e-02 | 1.006 | 168.10 | TRUE |
| d_matrix_read | 2.5e+07 | qs2_t1_l1 | 1.481e-01 | 1.971 | 168.20 | TRUE |
| d_matrix_read | 2.5e+07 | qs2_t4_l1 | 7.517e-02 | 1.000 | 168.20 | TRUE |
| d_matrix_read | 2.5e+07 | qd_t1 | 1.039e-01 | 1.382 | 168.10 | TRUE |
| d_matrix_read | 2.5e+07 | qd_t4 | 9.685e-02 | 1.288 | 168.10 | TRUE |
| d_matrix_read | 2.5e+07 | zap | 2.050e-01 | 2.727 | 170.00 | TRUE |
| d_matrix_read | 2.5e+07 | np_zstd_df | 1.413e-01 | 1.880 | 191.50 | FALSE |
| d_matrix_read | 2.5e+07 | arrow_zstd_df | 4.748e-01 | 6.316 | 222.40 | FALSE |
| e_model_write | 1.0e+00 | rds_gzip | 4.283e+00 | 29.400 | 94.69 | TRUE |
| e_model_write | 1.0e+00 | rds_none | 1.805e-01 | 1.239 | 114.40 | TRUE |
| e_model_write | 1.0e+00 | qs2_t1 | 2.520e-01 | 1.730 | 86.72 | TRUE |
| e_model_write | 1.0e+00 | qs2_t4 | 1.457e-01 | 1.000 | 86.72 | TRUE |
| e_model_write | 1.0e+00 | qd_t1 | 1.979e-01 | 1.358 | 33.77 | FALSE |
| e_model_write | 1.0e+00 | zap | 3.254e-01 | 2.233 | 87.62 | TRUE |
| e_model_read | 1.0e+00 | rds_gzip | 3.746e-01 | 3.911 | 94.69 | TRUE |
| e_model_read | 1.0e+00 | rds_none | 1.727e-01 | 1.803 | 114.40 | TRUE |
| e_model_read | 1.0e+00 | qs2_t1 | 1.656e-01 | 1.728 | 86.72 | TRUE |
| e_model_read | 1.0e+00 | qs2_t4 | 1.530e-01 | 1.597 | 86.72 | TRUE |
| e_model_read | 1.0e+00 | qd_t1 | 9.579e-02 | 1.000 | 33.77 | FALSE |
| e_model_read | 1.0e+00 | zap | 1.419e-01 | 1.481 | 87.62 | TRUE |
| e_model_write | 1.0e+00 | np_zstd | NA | NA | NA | NA |
| e_model_write | 1.0e+00 | arrow_zstd | NA | NA | NA | NA |
| altrep_qd_b2e5 | 2.0e+05 | qd_alt_read | 4.571e-01 | 1.080 | NA | NA |
| altrep_qd_b2e5 | 2.0e+05 | qd_noalt_read | 4.379e-01 | 1.035 | NA | NA |
| altrep_qd_b2e5 | 2.0e+05 | qd_alt_read_then_touch | 5.910e-01 | 1.397 | NA | NA |
| altrep_qd_b2e5 | 2.0e+05 | qd_noalt_read_then_touch | 5.872e-01 | 1.388 | NA | NA |
| altrep_qd_b2e5 | 2.0e+05 | qd_alt_read_touch_1pct | 4.232e-01 | 1.000 | NA | NA |
| a_numdf_threads_write | 2.5e+06 | qs2_t1 | 2.990e-01 | 3.106 | 94.06 | TRUE |
| a_numdf_threads_write | 2.5e+06 | qs2_t4 | 9.626e-02 | 1.000 | 94.06 | TRUE |
| a_numdf_threads_write | 2.5e+06 | qd_t1 | 3.079e-01 | 3.199 | 94.09 | TRUE |
| a_numdf_threads_write | 2.5e+06 | qd_t4 | 9.857e-02 | 1.024 | 94.09 | TRUE |
| a_numdf_threads_write | 2.5e+06 | arrow_zstd | 4.153e-01 | 4.315 | 117.10 | FALSE |
| a_numdf_threads_write | 2.5e+06 | arrow_zstd_1t | 4.161e-01 | 4.323 | 117.10 | FALSE |
| a_numdf_threads_write | 2.5e+06 | duck_zstd | 5.047e-01 | 5.243 | 106.30 | TRUE |
| a_numdf_threads_write | 2.5e+06 | duck_zstd_1t | 4.796e-01 | 4.982 | 106.30 | TRUE |
| a_numdf_threads_write | 2.5e+06 | np_zstd | 3.170e-01 | 3.293 | 127.30 | FALSE |
| a_numdf_threads_read | 2.5e+06 | qs2_t1 | 1.024e-01 | 4.176 | 94.06 | TRUE |
| a_numdf_threads_read | 2.5e+06 | qs2_t4 | 3.863e-02 | 1.575 | 94.06 | TRUE |
| a_numdf_threads_read | 2.5e+06 | qd_t1 | 9.937e-02 | 4.053 | 94.09 | TRUE |
| a_numdf_threads_read | 2.5e+06 | qd_t4 | 3.876e-02 | 1.581 | 94.09 | TRUE |
| a_numdf_threads_read | 2.5e+06 | arrow_zstd | 2.452e-02 | 1.000 | 117.10 | FALSE |
| a_numdf_threads_read | 2.5e+06 | arrow_zstd_1t | 1.205e-01 | 4.913 | 117.10 | FALSE |
| a_numdf_threads_read | 2.5e+06 | duck_zstd | 1.492e-01 | 6.084 | 106.30 | TRUE |
| a_numdf_threads_read | 2.5e+06 | duck_zstd_1t | 1.712e-01 | 6.981 | 106.30 | TRUE |
| a_numdf_threads_read | 2.5e+06 | np_zstd | 3.190e-02 | 1.301 | 127.30 | FALSE |
| b_chartbl_threads_write | 1.5e+05 | qs2_t1 | 4.707e-01 | 3.704 | 37.78 | TRUE |
| b_chartbl_threads_write | 1.5e+05 | qs2_t4 | 1.344e-01 | 1.058 | 37.78 | TRUE |
| b_chartbl_threads_write | 1.5e+05 | qd_t1 | 4.780e-01 | 3.761 | 37.50 | TRUE |
| b_chartbl_threads_write | 1.5e+05 | qd_t4 | 1.271e-01 | 1.000 | 37.50 | TRUE |
| b_chartbl_threads_write | 1.5e+05 | arrow_zstd | 5.138e-01 | 4.043 | 42.59 | TRUE |
| b_chartbl_threads_write | 1.5e+05 | arrow_zstd_1t | 5.008e-01 | 3.940 | 42.59 | TRUE |
| b_chartbl_threads_write | 1.5e+05 | duck_zstd | 2.292e-01 | 1.804 | 12.82 | FALSE |
| b_chartbl_threads_write | 1.5e+05 | duck_zstd_1t | 2.433e-01 | 1.915 | 12.82 | FALSE |
| b_chartbl_threads_write | 1.5e+05 | np_zstd | 1.279e-01 | 1.006 | 129.90 | FALSE |
| b_chartbl_threads_read | 1.5e+05 | qs2_t1 | 2.558e-01 | 3.004 | 37.78 | TRUE |
| b_chartbl_threads_read | 1.5e+05 | qs2_t4 | 1.524e-01 | 1.789 | 37.78 | TRUE |
| b_chartbl_threads_read | 1.5e+05 | qd_t1 | 2.692e-01 | 3.161 | 37.50 | TRUE |
| b_chartbl_threads_read | 1.5e+05 | qd_t4 | 1.580e-01 | 1.856 | 37.50 | TRUE |
| b_chartbl_threads_read | 1.5e+05 | arrow_zstd | 8.515e-02 | 1.000 | 42.59 | TRUE |
| b_chartbl_threads_read | 1.5e+05 | arrow_zstd_1t | 9.340e-02 | 1.097 | 42.59 | TRUE |
| b_chartbl_threads_read | 1.5e+05 | duck_zstd | 2.233e-01 | 2.622 | 12.82 | FALSE |
| b_chartbl_threads_read | 1.5e+05 | duck_zstd_1t | 2.239e-01 | 2.630 | 12.82 | FALSE |
| b_chartbl_threads_read | 1.5e+05 | np_zstd | 1.864e-01 | 2.189 | 129.90 | FALSE |
| a_partial_cols | 2.5e+06 | qs2_full_then_subset | 4.030e-02 | 2.215 | NA | TRUE |
| a_partial_cols | 2.5e+06 | qs2_t1_full_then_subset | 1.088e-01 | 5.981 | NA | TRUE |
| a_partial_cols | 2.5e+06 | np_full_then_subset | 1.693e-01 | 9.305 | NA | TRUE |
| a_partial_cols | 2.5e+06 | np_col_select | 6.098e-02 | 3.351 | NA | TRUE |
| a_partial_cols | 2.5e+06 | arrow_col_select | 1.820e-02 | 1.000 | NA | TRUE |
| a_partial_cols | 2.5e+06 | arrow_col_select_1t | 3.075e-02 | 1.689 | NA | TRUE |
| a_partial_cols | 2.5e+06 | duck_select | 3.690e-02 | 2.027 | NA | TRUE |
| a_partial_cols | 2.5e+06 | duck_select_1t | 3.692e-02 | 2.029 | NA | TRUE |
| a_partial_filter_rg10000_unsorted | 2.5e+06 | arrow_open_dataset_filter | 4.390e-02 | 1.000 | NA | TRUE |
| a_partial_filter_rg10000_unsorted | 2.5e+06 | arrow_filter_1t | 1.739e-01 | 3.962 | NA | TRUE |
| a_partial_filter_rg10000_unsorted | 2.5e+06 | duck_where | 1.418e-01 | 3.230 | NA | TRUE |
| a_partial_filter_rg10000_unsorted | 2.5e+06 | duck_where_1t | 1.363e-01 | 3.104 | NA | TRUE |
| a_partial_filter_rg10000_unsorted | 2.5e+06 | np_full_then_filter | 2.019e-01 | 4.600 | NA | TRUE |
| a_partial_filter_rg10000_sorted | 2.5e+06 | arrow_open_dataset_filter | 1.142e-02 | 1.000 | NA | TRUE |
| a_partial_filter_rg10000_sorted | 2.5e+06 | arrow_filter_1t | 1.767e-02 | 1.547 | NA | TRUE |
| a_partial_filter_rg10000_sorted | 2.5e+06 | duck_where | 1.665e-02 | 1.458 | NA | TRUE |
| a_partial_filter_rg10000_sorted | 2.5e+06 | duck_where_1t | 1.649e-02 | 1.444 | NA | TRUE |
| a_partial_filter_rg10000_sorted | 2.5e+06 | np_full_then_filter | 2.102e-01 | 18.410 | NA | TRUE |
| a_partial_filter_rg122880_unsorted | 2.5e+06 | arrow_open_dataset_filter | 3.384e-02 | 1.000 | NA | TRUE |
| a_partial_filter_rg122880_unsorted | 2.5e+06 | arrow_filter_1t | 1.453e-01 | 4.293 | NA | TRUE |
| a_partial_filter_rg122880_unsorted | 2.5e+06 | duck_where | 1.300e-01 | 3.842 | NA | TRUE |
| a_partial_filter_rg122880_unsorted | 2.5e+06 | duck_where_1t | 1.238e-01 | 3.659 | NA | TRUE |
| a_partial_filter_rg122880_unsorted | 2.5e+06 | np_full_then_filter | 1.902e-01 | 5.620 | NA | TRUE |
| a_partial_filter_rg122880_unsorted | 2.5e+06 | qs2_full_then_filter | 5.465e-02 | 1.615 | NA | TRUE |
| a_partial_filter_rg122880_sorted | 2.5e+06 | arrow_open_dataset_filter | 1.046e-02 | 1.000 | NA | TRUE |
| a_partial_filter_rg122880_sorted | 2.5e+06 | arrow_filter_1t | 2.028e-02 | 1.940 | NA | TRUE |
| a_partial_filter_rg122880_sorted | 2.5e+06 | duck_where | 1.710e-02 | 1.636 | NA | TRUE |
| a_partial_filter_rg122880_sorted | 2.5e+06 | duck_where_1t | 1.612e-02 | 1.542 | NA | TRUE |
| a_partial_filter_rg122880_sorted | 2.5e+06 | np_full_then_filter | 1.552e-01 | 14.850 | NA | TRUE |
| a_partial_filter_rg1000000_unsorted | 2.5e+06 | arrow_open_dataset_filter | 3.165e-02 | 1.000 | NA | TRUE |
| a_partial_filter_rg1000000_unsorted | 2.5e+06 | arrow_filter_1t | 1.386e-01 | 4.380 | NA | TRUE |
| a_partial_filter_rg1000000_unsorted | 2.5e+06 | duck_where | 1.339e-01 | 4.229 | NA | TRUE |
| a_partial_filter_rg1000000_unsorted | 2.5e+06 | duck_where_1t | 1.326e-01 | 4.189 | NA | TRUE |
| a_partial_filter_rg1000000_unsorted | 2.5e+06 | np_full_then_filter | 1.541e-01 | 4.870 | NA | TRUE |
| a_partial_filter_rg1000000_sorted | 2.5e+06 | arrow_open_dataset_filter | 2.496e-02 | 1.000 | NA | TRUE |
| a_partial_filter_rg1000000_sorted | 2.5e+06 | arrow_filter_1t | 6.292e-02 | 2.521 | NA | TRUE |
| a_partial_filter_rg1000000_sorted | 2.5e+06 | duck_where | 5.981e-02 | 2.396 | NA | TRUE |
| a_partial_filter_rg1000000_sorted | 2.5e+06 | duck_where_1t | 5.929e-02 | 2.375 | NA | TRUE |
| a_partial_filter_rg1000000_sorted | 2.5e+06 | np_full_then_filter | 1.496e-01 | 5.992 | NA | TRUE |
| b_partial_cols | 1.5e+05 | qs2_full_then_subset | 1.676e-01 | 219.500 | NA | TRUE |
| b_partial_cols | 1.5e+05 | qs2_t1_full_then_subset | 2.733e-01 | 358.000 | NA | TRUE |
| b_partial_cols | 1.5e+05 | np_full_then_subset | 9.929e-02 | 130.000 | NA | TRUE |
| b_partial_cols | 1.5e+05 | np_col_select | 7.635e-04 | 1.000 | NA | TRUE |
| b_partial_cols | 1.5e+05 | arrow_col_select | 2.179e-03 | 2.854 | NA | TRUE |
| b_partial_cols | 1.5e+05 | arrow_col_select_1t | 7.318e-03 | 9.584 | NA | TRUE |
| b_partial_cols | 1.5e+05 | duck_select | 9.311e-03 | 12.190 | NA | TRUE |
| b_partial_cols | 1.5e+05 | duck_select_1t | 9.591e-03 | 12.560 | NA | TRUE |
| b_partial_filter_rg10000_unsorted | 1.5e+05 | arrow_open_dataset_filter | 2.597e-02 | 1.000 | NA | TRUE |
| b_partial_filter_rg10000_unsorted | 1.5e+05 | arrow_filter_1t | 9.371e-02 | 3.609 | NA | TRUE |
| b_partial_filter_rg10000_unsorted | 1.5e+05 | duck_where | 1.136e-01 | 4.374 | NA | TRUE |
| b_partial_filter_rg10000_unsorted | 1.5e+05 | duck_where_1t | 1.123e-01 | 4.324 | NA | TRUE |
| b_partial_filter_rg10000_unsorted | 1.5e+05 | np_full_then_filter | 2.566e-01 | 9.881 | NA | TRUE |
| b_partial_filter_rg10000_sorted | 1.5e+05 | arrow_open_dataset_filter | 1.362e-02 | 1.000 | NA | TRUE |
| b_partial_filter_rg10000_sorted | 1.5e+05 | arrow_filter_1t | 1.859e-02 | 1.365 | NA | TRUE |
| b_partial_filter_rg10000_sorted | 1.5e+05 | duck_where | 1.899e-02 | 1.394 | NA | TRUE |
| b_partial_filter_rg10000_sorted | 1.5e+05 | duck_where_1t | 1.866e-02 | 1.370 | NA | TRUE |
| b_partial_filter_rg10000_sorted | 1.5e+05 | np_full_then_filter | 2.883e-01 | 21.180 | NA | TRUE |
| b_partial_filter_rg122880_unsorted | 1.5e+05 | arrow_open_dataset_filter | 3.839e-02 | 1.000 | NA | TRUE |
| b_partial_filter_rg122880_unsorted | 1.5e+05 | arrow_filter_1t | 6.037e-02 | 1.573 | NA | TRUE |
| b_partial_filter_rg122880_unsorted | 1.5e+05 | duck_where | 4.769e-02 | 1.242 | NA | TRUE |
| b_partial_filter_rg122880_unsorted | 1.5e+05 | duck_where_1t | 4.953e-02 | 1.290 | NA | TRUE |
| b_partial_filter_rg122880_unsorted | 1.5e+05 | np_full_then_filter | 9.594e-02 | 2.499 | NA | TRUE |
| b_partial_filter_rg122880_unsorted | 1.5e+05 | qs2_full_then_filter | 1.691e-01 | 4.403 | NA | TRUE |
| b_partial_filter_rg122880_sorted | 1.5e+05 | arrow_open_dataset_filter | 3.735e-02 | 1.278 | NA | TRUE |
| b_partial_filter_rg122880_sorted | 1.5e+05 | arrow_filter_1t | 4.724e-02 | 1.616 | NA | TRUE |
| b_partial_filter_rg122880_sorted | 1.5e+05 | duck_where | 2.983e-02 | 1.021 | NA | TRUE |
| b_partial_filter_rg122880_sorted | 1.5e+05 | duck_where_1t | 2.923e-02 | 1.000 | NA | TRUE |
| b_partial_filter_rg122880_sorted | 1.5e+05 | np_full_then_filter | 9.547e-02 | 3.266 | NA | TRUE |
| b_partial_filter_rg1000000_unsorted | 1.5e+05 | arrow_open_dataset_filter | 4.447e-02 | 1.431 | NA | TRUE |
| b_partial_filter_rg1000000_unsorted | 1.5e+05 | arrow_filter_1t | 5.313e-02 | 1.710 | NA | TRUE |
| b_partial_filter_rg1000000_unsorted | 1.5e+05 | duck_where | 3.206e-02 | 1.032 | NA | TRUE |
| b_partial_filter_rg1000000_unsorted | 1.5e+05 | duck_where_1t | 3.107e-02 | 1.000 | NA | TRUE |
| b_partial_filter_rg1000000_unsorted | 1.5e+05 | np_full_then_filter | 5.150e-02 | 1.658 | NA | TRUE |
| b_partial_filter_rg1000000_sorted | 1.5e+05 | arrow_open_dataset_filter | 4.122e-02 | 1.394 | NA | TRUE |
| b_partial_filter_rg1000000_sorted | 1.5e+05 | arrow_filter_1t | 5.234e-02 | 1.771 | NA | TRUE |
| b_partial_filter_rg1000000_sorted | 1.5e+05 | duck_where | 2.974e-02 | 1.006 | NA | TRUE |
| b_partial_filter_rg1000000_sorted | 1.5e+05 | duck_where_1t | 2.956e-02 | 1.000 | NA | TRUE |
| b_partial_filter_rg1000000_sorted | 1.5e+05 | np_full_then_filter | 5.531e-02 | 1.871 | NA | TRUE |

</details>

<details>

<summary>

Source: benchmark results `storage/targets_store.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 13 rows
</summary>

| task            |     n | method     |
|:----------------|------:|:-----------|
| b_targets_store | 2e+05 | noop       |
| b_targets_store | 2e+05 | sav_qs     |
| b_targets_store | 2e+05 | sav_qs4    |
| b_targets_store | 2e+05 | sav_qs4_l1 |
| b_targets_store | 2e+05 | sav_rds    |
| b_targets_store | 2e+05 | sav_np     |
| b_targets_store | 2e+05 | sav_fmt_np |
| b_targets_store | 2e+05 | d_qs       |
| b_targets_store | 2e+05 | d_qs4      |
| b_targets_store | 2e+05 | d_qs4_l1   |
| b_targets_store | 2e+05 | d_rds      |
| b_targets_store | 2e+05 | d_np       |
| b_targets_store | 2e+05 | d_fmt_np   |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c1_nproc.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`) 12 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| 24x2s | 24 | nproc=1 (serial, no controller) | 50.320 | 337.2 | 0 |
| 24x2s | 24 | nproc=2 (crew) | 26.890 | 761.4 | 0 |
| 24x2s | 24 | nproc=4 (crew) | 14.870 | 1166.0 | 0 |
| 24x2s | 24 | nproc=6 (crew) | 10.960 | 1580.0 | 0 |
| 24x2s | 24 | nproc=1 crew 1 worker | 51.340 | 555.3 | 0 |
| 200x20ms | 200 | serial | 5.201 | 337.7 | 0 |
| 200x20ms | 200 | serial | 5.104 | 338.9 | 0 |
| 200x20ms | 200 | crew nproc=2 deployment worker | 4.515 | 758.7 | 0 |
| 200x20ms | 200 | crew nproc=4 deployment worker | 3.382 | 1168.0 | 0 |
| 200x20ms | 200 | crew nproc=6 deployment worker | 3.223 | 1574.0 | 0 |
| 200x20ms | 200 | crew nproc=4, deployment main for tiny targets | 5.244 | 339.7 | 0 |
| 200x20ms | 200 | crew 1 worker deployment worker | 7.124 | 555.9 | 0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c2_startup.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`) 8 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| 24x2s_nproc4 | 24 | packages global(6 heavy); tasks_max Inf | 15.130 | 1311 | 0 |
| 24x2s_nproc4 | 24 | packages global(6 heavy); tasks_max 1 | 21.030 | 1316 | 0 |
| 24x2s_nproc4 | 24 | packages per-target(2 targets); tasks_max Inf | 14.810 | 1235 | 0 |
| 24x2s_nproc4 | 24 | packages per-target(2 targets); tasks_max 1 | 19.620 | 1209 | 0 |
| 24x0.2s_nproc4 | 24 | packages global(6 heavy); tasks_max Inf | 3.589 | 1311 | 0 |
| 24x0.2s_nproc4 | 24 | packages global(6 heavy); tasks_max 1 | 9.349 | 1315 | 0 |
| 24x0.2s_nproc4 | 24 | packages per-target(2 targets); tasks_max Inf | 3.522 | 1230 | 0 |
| 24x0.2s_nproc4 | 24 | packages per-target(2 targets); tasks_max 1 | 6.723 | 1191 | 0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c3_memory.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 30 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| big300_6consumers | 300 | serial memory=transient storage/retrieval=worker | 5.845 | 1679.0 | 6 |
| big300_6consumers | 300 | serial memory=transient storage/retrieval=main | 5.894 | 1680.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=transient storage/retrieval=worker | 6.289 | 3090.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=transient storage/retrieval=main | NA | 4238.0 | NA |
| big300_6consumers | 300 | serial memory=persistent storage/retrieval=worker | 5.837 | 2054.0 | 6 |
| big300_6consumers | 300 | serial memory=persistent storage/retrieval=main | 3.087 | 1593.0 | 0 |
| big300_6consumers | 300 | nproc=3 memory=persistent storage/retrieval=worker | 5.576 | 3266.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=persistent storage/retrieval=main | NA | 4220.0 | NA |
| big300_6consumers | 300 | serial memory=auto storage/retrieval=worker | 5.921 | 1684.0 | 6 |
| big300_6consumers | 300 | serial memory=auto storage/retrieval=main | 6.044 | 1680.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=auto storage/retrieval=worker | 5.930 | 3264.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=auto storage/retrieval=main | NA | 4253.0 | NA |
| big100_6consumers | 100 | serial memory=transient storage/retrieval=worker | 2.560 | 770.9 | 6 |
| big100_6consumers | 100 | serial memory=transient storage/retrieval=main | 2.546 | 764.9 | 6 |
| big100_6consumers | 100 | nproc=3 memory=transient storage/retrieval=worker | 3.571 | 1290.0 | 6 |
| big100_6consumers | 100 | nproc=3 memory=transient storage/retrieval=main | 3.864 | 2037.0 | 5 |
| big100_6consumers | 100 | serial memory=persistent storage/retrieval=worker | 2.573 | 991.0 | 6 |
| big100_6consumers | 100 | serial memory=persistent storage/retrieval=main | 1.543 | 647.7 | 0 |
| big100_6consumers | 100 | nproc=3 memory=persistent storage/retrieval=worker | 3.450 | 1436.0 | 6 |
| big100_6consumers | 100 | nproc=3 memory=persistent storage/retrieval=main | 3.149 | 2221.0 | 0 |
| big100_6consumers | 100 | serial memory=auto storage/retrieval=worker | 2.753 | 770.2 | 6 |
| big100_6consumers | 100 | serial memory=auto storage/retrieval=main | 2.712 | 765.4 | 6 |
| big100_6consumers | 100 | nproc=3 memory=auto storage/retrieval=worker | 3.611 | 1429.0 | 6 |
| big100_6consumers | 100 | nproc=3 memory=auto storage/retrieval=main | 3.752 | 2040.0 | 5 |
| big300_6consumers | 300 | serial memory=transient storage/retrieval=auto | 5.058 | 1678.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=transient storage/retrieval=auto | 5.202 | 3259.0 | 6 |
| big300_6consumers | 300 | serial memory=persistent storage/retrieval=auto | 5.112 | 2050.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=persistent storage/retrieval=auto | 5.212 | 3088.0 | 6 |
| big300_6consumers | 300 | serial memory=auto storage/retrieval=auto | 5.132 | 1678.0 | 6 |
| big300_6consumers | 300 | nproc=3 memory=auto storage/retrieval=auto | 5.254 | 3260.0 | 6 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c4_gc.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`) 18 rows
</summary>

| task      |   n | method             | wall_s | peak_rss_mb | loads |
|:----------|----:|:-------------------|-------:|------------:|------:|
| big300_gc | 300 | serial gc=0 rep1   |  5.927 |        1685 |     6 |
| big300_gc | 300 | serial gc=1 rep1   |  5.996 |        1680 |     6 |
| big300_gc | 300 | serial gc=10 rep1  |  5.841 |        1680 |     6 |
| big300_gc | 300 | nproc=3 gc=0 rep1  |  5.771 |        3263 |     6 |
| big300_gc | 300 | nproc=3 gc=1 rep1  |  5.957 |        3268 |     6 |
| big300_gc | 300 | nproc=3 gc=10 rep1 |  5.827 |        3093 |     6 |
| big300_gc | 300 | serial gc=0 rep2   |  5.833 |        1677 |     6 |
| big300_gc | 300 | serial gc=1 rep2   |  6.073 |        1681 |     6 |
| big300_gc | 300 | serial gc=10 rep2  |  5.852 |        1681 |     6 |
| big300_gc | 300 | nproc=3 gc=0 rep2  |  6.309 |        3091 |     6 |
| big300_gc | 300 | nproc=3 gc=1 rep2  |  5.886 |        3260 |     6 |
| big300_gc | 300 | nproc=3 gc=10 rep2 |  5.826 |        3268 |     6 |
| big300_gc | 300 | serial gc=0 rep3   |  5.964 |        1681 |     6 |
| big300_gc | 300 | serial gc=1 rep3   |  6.148 |        1680 |     6 |
| big300_gc | 300 | serial gc=10 rep3  |  5.741 |        1682 |     6 |
| big300_gc | 300 | nproc=3 gc=0 rep3  |  5.943 |        3091 |     6 |
| big300_gc | 300 | nproc=3 gc=1 rep3  |  6.203 |        3262 |     6 |
| big300_gc | 300 | nproc=3 gc=10 rep3 |  5.891 |        3266 |     6 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c5_mori.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 11 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| a_big100_nproc3 | 100 | no mori, worker retrieval | 7.027 | 3123.0 | 0 |
| a_big100_nproc3 | 100 | no mori, main retrieval (qs2) | 6.814 | 3124.0 | 0 |
| a_big100_nproc3 | 100 | mori format_qs_shared, main retrieval | 6.857 | 1920.0 | 0 |
| b_rerun_big100 | 100 | mori format_qs_shared: 2nd tar_make | 1.544 | 1920.0 | 0 |
| a_big300_nproc3 | 300 | no mori, worker retrieval | NA | 4654.0 | NA |
| a_big300_nproc3 | 300 | no mori, main retrieval (qs2) | NA | 4987.0 | NA |
| a_big300_nproc3 | 300 | mori format_qs_shared, main retrieval | 6.947 | 4154.0 | 0 |
| b_rerun_big300 | 300 | mori format_qs_shared: 2nd tar_make | 0.611 | 4154.0 | 0 |
| c_guard | 20 | mutate(big,z=1) result read in fresh session | 2.256 | 945.1 | 0 |
| d_antipattern | 20 | share() target cue always, memory=persistent | 3.533 | 820.4 | 0 |
| e_parquet | 20 | format_parquet_shared / unshared | 2.425 | 776.3 | 0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c5b_mori_marshal.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 13 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| e_marshal_100MB_nproc3 | 100 | (e0) format_qs_shared, consumers retrieval main rep1 | 4.733 | 1470.0 | 0 |
| e_marshal_100MB_nproc3 | 100 | \(e\) marshal format (plain object; share on ship), retrieval main rep1 | 4.599 | 1937.0 | 0 |
| e_marshal_100MB_nproc3 | 100 | \(f\) no mori, persistent, consumers deployment main rep1 | 7.584 | 730.6 | 0 |
| e_marshal_100MB_nproc3 | 100 | \(g\) retrieval worker, each consumer reads from disk rep1 | 5.663 | 1466.0 | 6 |
| e_marshal_100MB_nproc3 | 100 | (e0) format_qs_shared, consumers retrieval main rep2 | 4.538 | 1468.0 | 0 |
| e_marshal_100MB_nproc3 | 100 | \(e\) marshal format (plain object; share on ship), retrieval main rep2 | 4.559 | 1898.0 | 0 |
| e_marshal_100MB_nproc3 | 100 | \(f\) no mori, persistent, consumers deployment main rep2 | 7.603 | 709.4 | 0 |
| e_marshal_100MB_nproc3 | 100 | \(g\) retrieval worker, each consumer reads from disk rep2 | 5.584 | 1465.0 | 6 |
| e_marshal_300MB_nproc3 | 300 | (e0) format_qs_shared, consumers retrieval main | 5.916 | 2475.0 | 0 |
| e_marshal_300MB_nproc3 | 300 | \(e\) marshal format (plain object; share on ship), retrieval main | 5.799 | 3791.0 | 0 |
| e_marshal_300MB_nproc3 | 300 | \(f\) no mori, persistent, consumers deployment main | 8.806 | 1293.0 | 0 |
| e_marshal_rebuild_consumers | 100 | (e0) format_qs_shared, consumers retrieval main | 3.887 | 1526.0 | 0 |
| e_marshal_rebuild_consumers | 100 | \(e\) marshal format (plain object; share on ship), retrieval main | 3.920 | 1898.0 | 0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c6_branching.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`) 14 rows
</summary>

| task          |    n | method               | wall_s | peak_rss_mb | loads |
|:--------------|-----:|:---------------------|-------:|------------:|------:|
| 1e4rows_0.5ms |    1 | serial one target    |  5.896 |       340.3 |     0 |
| 1e4rows_0.5ms |   10 | serial list B=10     |  5.889 |       340.7 |     0 |
| 1e4rows_0.5ms |  100 | serial list B=100    |  6.142 |       345.4 |     0 |
| 1e4rows_0.5ms | 1000 | serial list B=1000   | 10.440 |       390.8 |     0 |
| 1e4rows_0.5ms |   10 | serial group B=10    |  5.819 |       341.0 |     0 |
| 1e4rows_0.5ms |  100 | serial group B=100   |  6.125 |       350.5 |     0 |
| 1e4rows_0.5ms | 1000 | serial group B=1000  |  8.523 |       433.6 |     0 |
| 1e4rows_0.5ms |    1 | nproc=4 one target   |  7.223 |       499.7 |     0 |
| 1e4rows_0.5ms |   10 | nproc=4 list B=10    |  3.941 |      1159.0 |     0 |
| 1e4rows_0.5ms |  100 | nproc=4 list B=100   |  3.758 |      1179.0 |     0 |
| 1e4rows_0.5ms | 1000 | nproc=4 list B=1000  |  6.092 |      1219.0 |     0 |
| 1e4rows_0.5ms |   10 | nproc=4 group B=10   |  3.881 |      1167.0 |     0 |
| 1e4rows_0.5ms |  100 | nproc=4 group B=100  |  4.089 |      1188.0 |     0 |
| 1e4rows_0.5ms | 1000 | nproc=4 group B=1000 |  5.416 |      1240.0 |     0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c6b_tar_rep.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`) 11 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| 1000reps_20ms | 1000 | serial tar_rep batches=1000 reps=1 | 23.920 | 384.0 | 0 |
| 1000reps_20ms | 100 | serial tar_rep batches=100 reps=10 | 22.510 | 343.2 | 0 |
| 1000reps_20ms | 40 | serial tar_rep batches=40 reps=25 | 22.340 | 341.0 | 0 |
| 1000reps_20ms | 10 | serial tar_rep batches=10 reps=100 | 22.310 | 345.8 | 0 |
| 1000reps_20ms | 1000 | nproc=4 tar_rep batches=1000 reps=1 | 9.505 | 1184.0 | 0 |
| 1000reps_20ms | 100 | nproc=4 tar_rep batches=100 reps=10 | 7.678 | 1166.0 | 0 |
| 1000reps_20ms | 40 | nproc=4 tar_rep batches=40 reps=25 | 7.345 | 1166.0 | 0 |
| 1000reps_20ms | 10 | nproc=4 tar_rep batches=10 reps=100 | 8.308 | 1161.0 | 0 |
| 1000reps_20ms | 8 | nproc=4 tar_rep batches=8 reps=125 | 7.743 | 1160.0 | 0 |
| 1000reps_20ms | 4 | nproc=4 tar_rep batches=4 reps=250 | 7.764 | 1154.0 | 0 |
| 1000reps_20ms | 20 | nproc=4 tar_map_rep 2 values x 10 batches x 50 reps | 7.690 | 1170.0 | 0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c6c_bigmap.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 16 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| 6branches_200MB | 6 | serial \[retrieval=worker\]: A map over group-iterated big table target | 7.840 | 1507.0 | 6 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=worker\]: A map over group-iterated big table target | 7.068 | 2793.0 | 7 |
| 6branches_200MB | 6 | serial \[retrieval=worker\]: B map over list-of-chunks target (one stored object) | 7.876 | 1518.0 | 6 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=worker\]: B map over list-of-chunks target (one stored object) | 7.116 | 2163.0 | 7 |
| 6branches_200MB | 6 | serial \[retrieval=worker\]: C branches use the whole table as static dependency | 7.362 | 1147.0 | 6 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=worker\]: C branches use the whole table as static dependency | 6.442 | 2081.0 | 6 |
| 6branches_200MB | 6 | serial \[retrieval=worker\]: D chunks produced per branch (dynamic chunk target) | 5.600 | 569.1 | 6 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=worker\]: D chunks produced per branch (dynamic chunk target) | 4.204 | 1444.0 | 6 |
| 6branches_200MB | 6 | serial \[retrieval=auto\]: A map over group-iterated big table target | 5.468 | 1343.0 | 0 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=auto\]: A map over group-iterated big table target | 5.623 | 2390.0 | 1 |
| 6branches_200MB | 6 | serial \[retrieval=auto\]: B map over list-of-chunks target (one stored object) | 5.298 | 1428.0 | 0 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=auto\]: B map over list-of-chunks target (one stored object) | 5.595 | 1990.0 | 1 |
| 6branches_200MB | 6 | serial \[retrieval=auto\]: C branches use the whole table as static dependency | 6.942 | 1195.0 | 6 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=auto\]: C branches use the whole table as static dependency | 6.003 | 3544.0 | 6 |
| 6branches_200MB | 6 | serial \[retrieval=auto\]: D chunks produced per branch (dynamic chunk target) | 5.427 | 563.7 | 6 |
| 6branches_200MB | 6 | nproc=3 \[retrieval=auto\]: D chunks produced per branch (dynamic chunk target) | 3.940 | 1445.0 | 6 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c7_static.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`) 12 rows
</summary>

| task            |   n | method              | wall_s | peak_rss_mb | loads |
|:----------------|----:|:--------------------|-------:|------------:|------:|
| n_x_50ms_serial |   6 | static tar_map rep1 |  0.975 |       341.0 |     0 |
| n_x_50ms_serial |   6 | dynamic map rep1    |  1.045 |       340.6 |     0 |
| n_x_50ms_serial |   6 | static tar_map rep2 |  0.949 |       341.1 |     0 |
| n_x_50ms_serial |   6 | dynamic map rep2    |  1.078 |       340.7 |     0 |
| n_x_50ms_serial |  60 | static tar_map rep1 |  3.849 |       340.8 |     0 |
| n_x_50ms_serial |  60 | dynamic map rep1    |  3.957 |       341.0 |     0 |
| n_x_50ms_serial |  60 | static tar_map rep2 |  3.847 |       340.8 |     0 |
| n_x_50ms_serial |  60 | dynamic map rep2    |  3.883 |       340.9 |     0 |
| n_x_50ms_serial | 300 | static tar_map rep1 | 16.840 |       340.7 |     0 |
| n_x_50ms_serial | 300 | dynamic map rep1    | 16.990 |       344.8 |     0 |
| n_x_50ms_serial | 300 | static tar_map rep2 | 17.040 |       337.6 |     0 |
| n_x_50ms_serial | 300 | dynamic map rep2    | 16.850 |       343.5 |     0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c8_level.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03; `retrieval = "worker"`) 12 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| dt_6jobs | 6 | 1 target, 6 jobs sequential, DT threads = 6 rep1 | 4.715 | 792.4 | 0 |
| dt_6jobs | 1 | 1 target, 6 jobs sequential, DT threads = 1 rep1 | 9.145 | 783.4 | 0 |
| dt_6jobs | 1 | 6 branches x 1 thread, NPROC=6 rep1 | 5.012 | 3350.0 | 0 |
| dt_6jobs | 2 | 6 branches x 2 threads, NPROC=6 (=12 threads) rep1 | 4.894 | 3347.0 | 0 |
| dt_6jobs | 6 | 6 branches x 6 threads, NPROC=6 (36 threads, oversubscribed) rep1 | 6.165 | 3383.0 | 0 |
| dt_6jobs | 12 | 6 branches x 12 threads, NPROC=6 (72 threads) rep1 | 11.400 | 3423.0 | 0 |
| dt_6jobs | 6 | 1 target, 6 jobs sequential, DT threads = 6 rep2 | 5.647 | 786.6 | 0 |
| dt_6jobs | 1 | 1 target, 6 jobs sequential, DT threads = 1 rep2 | 9.517 | 782.8 | 0 |
| dt_6jobs | 1 | 6 branches x 1 thread, NPROC=6 rep2 | 5.231 | 3366.0 | 0 |
| dt_6jobs | 2 | 6 branches x 2 threads, NPROC=6 (=12 threads) rep2 | 4.502 | 3346.0 | 0 |
| dt_6jobs | 6 | 6 branches x 6 threads, NPROC=6 (36 threads, oversubscribed) rep2 | 5.291 | 3375.0 | 0 |
| dt_6jobs | 12 | 6 branches x 12 threads, NPROC=6 (72 threads) rep2 | 13.490 | 3414.0 | 0 |

</details>

<details>

<summary>

Source: benchmark results `targets_mech/c9_partial.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 23 rows
</summary>

| task | n | method | wall_s | peak_rss_mb | loads |
|:---|---:|:---|---:|---:|---:|
| a_dependency | 5 | path via tar_path_target(big) symbol | 0.656 | 279.3 | 0 |
| a_dependency | 5 | if (FALSE) big | 0.679 | 280.1 | 0 |
| a_dependency | 5 | tar_target_raw(deps = 'big') | 0.653 | 288.3 | 0 |
| a_dependency | 5 | tar_read(big) in command (loads all) | NA | NA | NA |
| a_dependency | 5 | path string only (undeclared) | NA | NA | NA |
| b_serial_300MB | 300 | normal retrieval, then subset 2 cols (nanoparquet format) | 0.832 | 577.5 | 0 |
| b_serial_300MB | 300 | retrieval none + nanoparquet col_select 2 cols | 0.634 | 291.2 | 0 |
| b_serial_300MB | 300 | retrieval none + arrow open_dataset select 2 cols | 0.801 | 538.5 | 0 |
| b_serial_300MB | 300 | retrieval none + duckdb sum(x1),sum(x2) | 0.588 | 406.2 | 0 |
| b_serial_300MB | 300 | normal retrieval, then filter x1 \< 0.01 (1% rows) | 0.844 | 565.7 | 0 |
| b_serial_300MB | 300 | retrieval none + arrow filter x1 \< 0.01 | 0.636 | 322.5 | 0 |
| b_serial_300MB | 300 | retrieval none + duckdb filter x1 \< 0.01 | 0.589 | 315.8 | 0 |
| b_serial_300MB | 300 | qs2 format big: normal retrieval then subset | 1.072 | 549.3 | 0 |
| b_serial_300MB | 300 | qs2 format big: retrieval none + qs2::qs_read whole then subset | 1.071 | 551.2 | 0 |
| c_nproc3_300MB | 300 | nproc=3 normal retrieval=worker | 2.101 | 1813.0 | 0 |
| c_nproc3_300MB | 300 | nproc=3 normal retrieval=main (big shipped by main) | 2.396 | 4534.0 | 0 |
| c_nproc3_300MB | 300 | nproc=3 retrieval=none storage=worker, nanoparquet col_select | 1.892 | 763.6 | 0 |
| c_nproc3_300MB | 300 | nproc=3 retrieval=none storage=main, nanoparquet col_select | 1.913 | 1116.0 | 0 |
| c_nproc3_300MB | 300 | nproc=3 qs2 big, retrieval=none, qs_read whole then subset | 2.254 | 1664.0 | 0 |
| d_file_target_300MB | 300 | format = file parquet target; consumer reads path with col_select | 0.634 | 291.0 | 0 |
| d_file_target_300MB_uptodate | 300 | format = file: up-to-date make (rehashes file) | 0.429 | 1236.0 | 0 |
| d_file_target_300MB_uptodate | 300 | format parquet (nanoparquet) store target: up-to-date make | 0.437 | 1351.0 | 0 |
| t_store_arg | 5 | tar_make(store = 'alt_store'): tar_path_target(big) inside command | 0.651 | 274.8 | 0 |

</details>

<details>

<summary>

Source: benchmark results `vectorize/b1_rbind.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-02, 2026-11-03) 47 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| rbind 100 dfs x 10 rows | 1e+03 | do_call_rbind | 0.0015560 | 49.110 | TRUE |
| rbind 100 dfs x 10 rows | 1e+03 | list_rbind | 0.0002184 | 6.894 | TRUE |
| rbind 100 dfs x 10 rows | 1e+03 | rbindlist | 0.0001019 | 3.217 | TRUE |
| rbind 100 dfs x 10 rows | 1e+03 | collapse_rowbind | 0.0000341 | 1.076 | TRUE |
| rbind 100 dfs x 10 rows | 1e+03 | collapse_rbind | 0.0000317 | 1.000 | TRUE |
| rbind 100 dfs x 10 rows | 1e+03 | Reduce_rbind | 0.0044370 | 140.100 | TRUE |
| rbind 100 dfs x 10 rows | 1e+03 | vec_rbind | 0.0002332 | 7.364 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | do_call_rbind | 0.0160800 | 60.230 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | list_rbind | 0.0019800 | 7.416 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | rbindlist | 0.0005146 | 1.927 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | collapse_rowbind | 0.0002919 | 1.093 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | collapse_rbind | 0.0002670 | 1.000 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | Reduce_rbind | 0.1286000 | 481.600 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | vec_rbind | 0.0068730 | 25.740 | TRUE |
| rbind 10000 dfs x 10 rows | 1e+05 | do_call_rbind | 0.1988000 | 55.030 | TRUE |
| rbind 10000 dfs x 10 rows | 1e+05 | list_rbind | 0.0263700 | 7.301 | TRUE |
| rbind 10000 dfs x 10 rows | 1e+05 | rbindlist | 0.0080290 | 2.223 | TRUE |
| rbind 10000 dfs x 10 rows | 1e+05 | collapse_rowbind | 0.0040640 | 1.125 | TRUE |
| rbind 10000 dfs x 10 rows | 1e+05 | collapse_rbind | 0.0036120 | 1.000 | TRUE |
| rbind 10000 dfs x 10 rows | 1e+05 | vec_rbind | 0.9560000 | 264.600 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | do_call_rbind | 0.0084240 | 89.580 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | list_rbind | 0.0008424 | 8.958 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | rbindlist | 0.0006757 | 7.186 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | collapse_rowbind | 0.0000963 | 1.024 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | collapse_rbind | 0.0000940 | 1.000 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | Reduce_rbind | 0.1079000 | 1148.000 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | vec_rbind | 0.0012250 | 13.030 | TRUE |
| rbind 10 dfs x 100000 rows | 1e+06 | do_call_rbind | 0.0288100 | 63.930 | TRUE |
| rbind 10 dfs x 100000 rows | 1e+06 | list_rbind | 0.0061390 | 13.620 | TRUE |
| rbind 10 dfs x 100000 rows | 1e+06 | rbindlist | 0.0058020 | 12.880 | TRUE |
| rbind 10 dfs x 100000 rows | 1e+06 | collapse_rowbind | 0.0004673 | 1.037 | TRUE |
| rbind 10 dfs x 100000 rows | 1e+06 | collapse_rbind | 0.0004506 | 1.000 | TRUE |
| rbind 10 dfs x 100000 rows | 1e+06 | Reduce_rbind | 0.0812000 | 180.200 | TRUE |
| rbind 10 dfs x 100000 rows | 1e+06 | vec_rbind | 0.0095370 | 21.170 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | do_call_rbind | 0.1033000 | 40.810 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | list_rbind | 0.0334400 | 13.220 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | rbindlist | 0.0297400 | 11.750 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | collapse_rowbind | 0.0027440 | 1.084 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | collapse_rbind | 0.0025300 | 1.000 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | Reduce_rbind | 0.2197000 | 86.820 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | vec_rbind | 0.0488600 | 19.310 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | rbindlist_1thread | 0.0005472 | 1.924 | TRUE |
| rbind 1000 dfs x 10 rows | 1e+04 | collapse_rowbind_1thread | 0.0002844 | 1.000 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | rbindlist_1thread | 0.0007251 | 7.434 | TRUE |
| rbind 100 dfs x 1000 rows | 1e+05 | collapse_rowbind_1thread | 0.0000975 | 1.000 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | rbindlist_1thread | 0.0353600 | 11.500 | TRUE |
| rbind 5 dfs x 1e+06 rows | 5e+06 | collapse_rowbind_1thread | 0.0030750 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `vectorize/b2_groups.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 64 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| group mean, 1000 rows, 10 groups | 1e+03 | split_lapply | 0.0000487 | 5.798 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | tapply | 0.0000644 | 7.666 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | split_df_map | 0.0001950 | 23.200 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | rowsum_tabulate | 0.0000438 | 5.212 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | collapse_fmean | 0.0000084 | 1.000 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | collapse_fmean_GRP | 0.0000179 | 2.134 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | dt_by | 0.0002915 | 34.680 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | dplyr_by | 0.0008145 | 96.900 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | dt_by_1thread | 0.0002227 | 26.500 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | collapse_fmean_1thread | 0.0000084 | 1.000 | TRUE |
| group mean, 1000 rows, 10 groups | 1e+03 | collapse_fmean_4threads | 0.0000082 | 1.000 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | split_lapply | 0.0001902 | 20.990 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | tapply | 0.0002019 | 22.280 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | split_df_map | 0.0013570 | 149.700 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | rowsum_tabulate | 0.0000456 | 5.027 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | collapse_fmean | 0.0000091 | 1.000 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | collapse_fmean_GRP | 0.0000175 | 1.928 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | dt_by | 0.0002944 | 32.490 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | dplyr_by | 0.0011150 | 123.100 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | dt_by_1thread | 0.0002192 | 25.280 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | collapse_fmean_1thread | 0.0000087 | 1.000 | TRUE |
| group mean, 1000 rows, 100 groups | 1e+03 | collapse_fmean_4threads | 0.0000087 | 1.000 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | split_lapply | 0.0013890 | 8.015 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | tapply | 0.0019740 | 11.400 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | split_df_map | 0.0036450 | 21.040 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | rowsum_tabulate | 0.0013560 | 7.829 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | collapse_fmean | 0.0001732 | 1.000 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | collapse_fmean_GRP | 0.0003145 | 1.815 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | dt_by | 0.0010950 | 6.323 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | dplyr_by | 0.0014260 | 8.233 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | dt_by_1thread | 0.0019560 | 10.680 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | collapse_fmean_1thread | 0.0001832 | 1.000 | TRUE |
| group mean, 100000 rows, 10 groups | 1e+05 | collapse_fmean_4threads | 0.0001892 | 1.000 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | split_lapply | 0.0259700 | 70.250 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | tapply | 0.0247400 | 66.950 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | rowsum_tabulate | 0.0055050 | 14.900 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | collapse_fmean | 0.0003696 | 1.000 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | collapse_fmean_GRP | 0.0004247 | 1.149 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | dt_by | 0.0010460 | 2.829 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | dplyr_by | 0.0398300 | 107.800 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | dt_by_1thread | 0.0014030 | 3.668 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | collapse_fmean_1thread | 0.0003825 | 1.000 | TRUE |
| group mean, 100000 rows, 10000 groups | 1e+05 | collapse_fmean_4threads | 0.0003659 | 1.000 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | split_lapply | 0.0142000 | 9.028 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | tapply | 0.0208200 | 13.240 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | split_df_map | 0.0290700 | 18.480 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | rowsum_tabulate | 0.0140000 | 8.897 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | collapse_fmean | 0.0015730 | 1.000 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | collapse_fmean_GRP | 0.0030350 | 1.929 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | dt_by | 0.0064680 | 4.111 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | dplyr_by | 0.0074200 | 4.717 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | dt_by_1thread | 0.0149800 | 9.549 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | collapse_fmean_1thread | 0.0015680 | 1.000 | TRUE |
| group mean, 1e+06 rows, 10 groups | 1e+06 | collapse_fmean_4threads | 0.0015710 | 1.000 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | split_lapply | 0.3462000 | 55.790 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | tapply | 0.3250000 | 52.380 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | rowsum_tabulate | 0.0916300 | 14.770 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | collapse_fmean | 0.0068840 | 1.109 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | collapse_fmean_GRP | 0.0062040 | 1.000 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | dt_by | 0.0116500 | 1.878 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | dplyr_by | 0.3435000 | 55.370 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | dt_by_1thread | 0.0238300 | 3.395 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | collapse_fmean_1thread | 0.0070190 | 1.000 | TRUE |
| group mean, 1e+06 rows, 100000 groups | 1e+06 | collapse_fmean_4threads | 0.0070760 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `vectorize/b3_elementwise.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 57 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| scalar op over vector | 1e+03 | sapply | 0.0002810 | 50.390 | TRUE |
| scalar op over vector | 1e+03 | vapply | 0.0005334 | 95.670 | TRUE |
| scalar op over vector | 1e+03 | map_dbl | 0.0002859 | 51.280 | TRUE |
| scalar op over vector | 1e+03 | lapply_unlist | 0.0002657 | 47.650 | TRUE |
| scalar op over vector | 1e+03 | vectorized | 0.0000205 | 3.684 | TRUE |
| scalar op over vector | 1e+03 | vec_fifelse | 0.0000056 | 1.000 | TRUE |
| scalar op over vector | 1e+03 | vec_arith | 0.0000205 | 3.684 | TRUE |
| sqrt over vector | 1e+03 | lapply_unlist | 0.0002458 | 101.600 | TRUE |
| sqrt over vector | 1e+03 | map_dbl | 0.0001671 | 69.060 | TRUE |
| sqrt over vector | 1e+03 | vectorized | 0.0000024 | 1.000 | TRUE |
| scalar op over vector | 1e+05 | sapply | 0.1082000 | 131.000 | TRUE |
| scalar op over vector | 1e+05 | vapply | 0.0583500 | 70.630 | TRUE |
| scalar op over vector | 1e+05 | map_dbl | 0.0468400 | 56.700 | TRUE |
| scalar op over vector | 1e+05 | lapply_unlist | 0.0922800 | 111.700 | TRUE |
| scalar op over vector | 1e+05 | vectorized | 0.0019850 | 2.402 | TRUE |
| scalar op over vector | 1e+05 | vec_fifelse | 0.0008261 | 1.000 | TRUE |
| scalar op over vector | 1e+05 | vec_arith | 0.0027240 | 3.297 | TRUE |
| sqrt over vector | 1e+05 | lapply_unlist | 0.0257300 | 111.900 | TRUE |
| sqrt over vector | 1e+05 | map_dbl | 0.0244500 | 106.400 | TRUE |
| sqrt over vector | 1e+05 | vectorized | 0.0002298 | 1.000 | TRUE |
| scalar op over vector | 1e+06 | sapply | 0.8367000 | 81.740 | TRUE |
| scalar op over vector | 1e+06 | vapply | 0.5601000 | 54.710 | TRUE |
| scalar op over vector | 1e+06 | map_dbl | 0.5442000 | 53.160 | TRUE |
| scalar op over vector | 1e+06 | lapply_unlist | 0.9880000 | 96.520 | TRUE |
| scalar op over vector | 1e+06 | vectorized | 0.0596600 | 5.828 | TRUE |
| scalar op over vector | 1e+06 | vec_fifelse | 0.0102400 | 1.000 | TRUE |
| scalar op over vector | 1e+06 | vec_arith | 0.0387400 | 3.785 | TRUE |
| sqrt over vector | 1e+06 | lapply_unlist | 0.3484000 | 94.140 | TRUE |
| sqrt over vector | 1e+06 | map_dbl | 0.2495000 | 67.430 | TRUE |
| sqrt over vector | 1e+06 | vectorized | 0.0037010 | 1.000 | TRUE |
| row mean/sum of 10-col matrix | 1e+03 | apply_mean | 0.0035610 | 811.700 | TRUE |
| row mean/sum of 10-col matrix | 1e+03 | apply_sum_div | 0.0005412 | 123.400 | TRUE |
| row mean/sum of 10-col matrix | 1e+03 | rowMeans | 0.0000044 | 1.000 | TRUE |
| row mean/sum of 10-col matrix | 1e+03 | Rfast_rowmeans | 0.0000046 | 1.056 | TRUE |
| row mean/sum of 10-col matrix | 1e+03 | collapse_fmean_t | 0.0000345 | 7.860 | TRUE |
| row mean/sum of 10-col matrix | 1e+03 | reduce_plus | 0.0001283 | 29.250 | TRUE |
| row var of 10-col matrix | 1e+03 | apply_var | 0.0039250 | 291.000 | TRUE |
| row var of 10-col matrix | 1e+03 | Rfast_rowVars | 0.0000137 | 1.014 | TRUE |
| row var of 10-col matrix | 1e+03 | vector_formula | 0.0000135 | 1.000 | TRUE |
| row mean/sum of 10-col matrix | 1e+05 | apply_mean | 0.3655000 | 985.400 | TRUE |
| row mean/sum of 10-col matrix | 1e+05 | apply_sum_div | 0.1352000 | 364.600 | TRUE |
| row mean/sum of 10-col matrix | 1e+05 | rowMeans | 0.0003709 | 1.000 | TRUE |
| row mean/sum of 10-col matrix | 1e+05 | Rfast_rowmeans | 0.0009479 | 2.556 | TRUE |
| row mean/sum of 10-col matrix | 1e+05 | collapse_fmean_t | 0.0040790 | 11.000 | TRUE |
| row mean/sum of 10-col matrix | 1e+05 | reduce_plus | 0.0130100 | 35.080 | TRUE |
| row var of 10-col matrix | 1e+05 | apply_var | 0.5328000 | 508.700 | TRUE |
| row var of 10-col matrix | 1e+05 | Rfast_rowVars | 0.0012990 | 1.240 | TRUE |
| row var of 10-col matrix | 1e+05 | vector_formula | 0.0010470 | 1.000 | TRUE |
| row mean/sum of 10-col matrix | 1e+06 | apply_mean | 2.5750000 | 687.100 | TRUE |
| row mean/sum of 10-col matrix | 1e+06 | apply_sum_div | 1.3430000 | 358.500 | TRUE |
| row mean/sum of 10-col matrix | 1e+06 | rowMeans | 0.0037470 | 1.000 | TRUE |
| row mean/sum of 10-col matrix | 1e+06 | Rfast_rowmeans | 0.0048570 | 1.296 | TRUE |
| row mean/sum of 10-col matrix | 1e+06 | collapse_fmean_t | 0.0258800 | 6.906 | TRUE |
| row mean/sum of 10-col matrix | 1e+06 | reduce_plus | 0.2696000 | 71.950 | TRUE |
| row var of 10-col matrix | 1e+06 | apply_var | 6.6960000 | 285.500 | TRUE |
| row var of 10-col matrix | 1e+06 | Rfast_rowVars | 0.0234500 | 1.000 | TRUE |
| row var of 10-col matrix | 1e+06 | vector_formula | 0.0718600 | 3.064 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `vectorize/b4_pairs.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 58 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| pairwise min | 1e+03 | mapply_min | 0.0003832 | 42.880 | TRUE |
| pairwise min | 1e+03 | map2_dbl | 0.0003495 | 39.110 | TRUE |
| pairwise min | 1e+03 | pmin | 0.0000116 | 1.298 | TRUE |
| pairwise min | 1e+03 | ifelse | 0.0000290 | 3.245 | TRUE |
| pairwise min | 1e+03 | fifelse | 0.0000089 | 1.000 | TRUE |
| pairwise min | 1e+03 | kit_iif | 0.0000090 | 1.002 | TRUE |
| pairwise min (map2 1e6 incl) | 1e+03 | map2_dbl | 0.0003981 | 61.450 | TRUE |
| pairwise min (map2 1e6 incl) | 1e+03 | pmin | 0.0000065 | 1.000 | TRUE |
| flatten list of scalars | 1e+03 | do_call_c | 0.0000374 | 3.325 | TRUE |
| flatten list of scalars | 1e+03 | unlist | 0.0000112 | 1.000 | TRUE |
| flatten list of scalars | 1e+03 | vec_c | 0.0001113 | 9.905 | TRUE |
| flatten list of scalars | 1e+03 | purrr_list_c | 0.0001492 | 13.280 | TRUE |
| flatten list of scalars | 1e+03 | sapply_identity | 0.0002307 | 20.530 | TRUE |
| recode 3 levels | 1e+03 | sapply_switch | 0.0001991 | 18.890 | TRUE |
| recode 3 levels | 1e+03 | case_when | 0.0000622 | 5.903 | TRUE |
| recode 3 levels | 1e+03 | fcase | 0.0000204 | 1.938 | TRUE |
| recode 3 levels | 1e+03 | lookup | 0.0000134 | 1.272 | TRUE |
| recode 3 levels | 1e+03 | match_idx | 0.0000105 | 1.000 | TRUE |
| pairwise min | 1e+05 | mapply_min | 0.0872600 | 224.200 | TRUE |
| pairwise min | 1e+05 | map2_dbl | 0.0723000 | 185.800 | TRUE |
| pairwise min | 1e+05 | pmin | 0.0005643 | 1.450 | TRUE |
| pairwise min | 1e+05 | ifelse | 0.0018130 | 4.660 | TRUE |
| pairwise min | 1e+05 | fifelse | 0.0003891 | 1.000 | TRUE |
| pairwise min | 1e+05 | kit_iif | 0.0004345 | 1.116 | TRUE |
| pairwise min (map2 1e6 incl) | 1e+05 | map2_dbl | 0.0453400 | 21.420 | TRUE |
| pairwise min (map2 1e6 incl) | 1e+05 | pmin | 0.0021170 | 1.000 | TRUE |
| flatten list of scalars | 1e+05 | do_call_c | 0.0091000 | 5.744 | TRUE |
| flatten list of scalars | 1e+05 | unlist | 0.0015840 | 1.000 | TRUE |
| flatten list of scalars | 1e+05 | vec_c | 0.0131600 | 8.308 | TRUE |
| flatten list of scalars | 1e+05 | purrr_list_c | 0.0125100 | 7.897 | TRUE |
| flatten list of scalars | 1e+05 | sapply_identity | 0.0296800 | 18.730 | TRUE |
| recode 3 levels | 1e+05 | sapply_switch | 0.0211700 | 23.230 | TRUE |
| recode 3 levels | 1e+05 | case_when | 0.0021470 | 2.355 | TRUE |
| recode 3 levels | 1e+05 | fcase | 0.0023290 | 2.556 | TRUE |
| recode 3 levels | 1e+05 | lookup | 0.0013190 | 1.448 | TRUE |
| recode 3 levels | 1e+05 | match_idx | 0.0009114 | 1.000 | TRUE |
| pairwise min | 1e+06 | pmin | 0.0060800 | 4.300 | TRUE |
| pairwise min | 1e+06 | ifelse | 0.0146600 | 10.370 | TRUE |
| pairwise min | 1e+06 | fifelse | 0.0025420 | 1.798 | TRUE |
| pairwise min | 1e+06 | kit_iif | 0.0014140 | 1.000 | TRUE |
| pairwise min (map2 1e6 incl) | 1e+06 | map2_dbl | 0.3849000 | 46.030 | TRUE |
| pairwise min (map2 1e6 incl) | 1e+06 | pmin | 0.0083620 | 1.000 | TRUE |
| flatten list of scalars | 1e+06 | do_call_c | 0.0962900 | 5.572 | TRUE |
| flatten list of scalars | 1e+06 | unlist | 0.0172800 | 1.000 | TRUE |
| flatten list of scalars | 1e+06 | vec_c | 0.1307000 | 7.565 | TRUE |
| flatten list of scalars | 1e+06 | purrr_list_c | 0.1248000 | 7.219 | TRUE |
| flatten list of scalars | 1e+06 | sapply_identity | 0.2554000 | 14.780 | TRUE |
| recode 3 levels | 1e+06 | sapply_switch | 0.2286000 | 18.220 | TRUE |
| recode 3 levels | 1e+06 | case_when | 0.0235500 | 1.877 | TRUE |
| recode 3 levels | 1e+06 | fcase | 0.0270700 | 2.157 | TRUE |
| recode 3 levels | 1e+06 | lookup | 0.0162300 | 1.294 | TRUE |
| recode 3 levels | 1e+06 | match_idx | 0.0125500 | 1.000 | TRUE |
| pairwise min | 1e+05 | fifelse_1thread | 0.0002562 | 1.000 | TRUE |
| pairwise min | 1e+05 | kit_iif_1thread | 0.0003564 | 1.391 | TRUE |
| pairwise min | 1e+05 | kit_iif_4threads | 0.0001675 | 1.000 | TRUE |
| pairwise min | 1e+06 | fifelse_1thread | 0.0034560 | 1.396 | TRUE |
| pairwise min | 1e+06 | kit_iif_1thread | 0.0024760 | 1.000 | TRUE |
| pairwise min | 1e+06 | kit_iif_4threads | 0.0021730 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `vectorize/b5_text.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 35 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| any of 10 terms in text | 1e+03 | map_str_detect | 0.002187 | 1.077 | TRUE |
| any of 10 terms in text | 1e+03 | map_stri_fixed | 0.002033 | 1.001 | TRUE |
| any of 10 terms in text | 1e+03 | stri_fixed_outer | 0.002345 | 1.155 | TRUE |
| any of 10 terms in text | 1e+03 | stri_fixed_outer_loop | 0.002030 | 1.000 | TRUE |
| any of 10 terms in text | 1e+03 | alternation_regex | 0.008470 | 4.172 | TRUE |
| any of 10 terms in text | 1e+03 | base_grepl_fixed_loop | 0.002032 | 1.001 | TRUE |
| any of 10 terms in text | 1e+03 | per_doc_map | 0.003474 | 1.711 | TRUE |
| count 200 terms (per-term totals) | 1e+03 | loop_count | 0.040450 | 1.155 | TRUE |
| count 200 terms (per-term totals) | 1e+03 | one_collapsed_text | 0.035020 | 1.000 | TRUE |
| replace 200-term dictionary | 1e+03 | loop | 0.041320 | 1.101 | TRUE |
| replace 200-term dictionary | 1e+03 | vectorize_all_FALSE | 0.037520 | 1.000 | TRUE |
| replace 200-term dictionary | 1e+03 | purrr_reduce | 0.041820 | 1.115 | TRUE |
| replace 200-term dictionary | 1e+03 | base_gsub_fixed_loop | 0.042390 | 1.130 | TRUE |
| any of 10 terms in text | 1e+04 | map_str_detect | 0.020600 | 1.021 | TRUE |
| any of 10 terms in text | 1e+04 | map_stri_fixed | 0.020340 | 1.008 | TRUE |
| any of 10 terms in text | 1e+04 | stri_fixed_outer | 0.023600 | 1.170 | TRUE |
| any of 10 terms in text | 1e+04 | stri_fixed_outer_loop | 0.020180 | 1.000 | TRUE |
| any of 10 terms in text | 1e+04 | alternation_regex | 0.081490 | 4.038 | TRUE |
| any of 10 terms in text | 1e+04 | base_grepl_fixed_loop | 0.020710 | 1.026 | TRUE |
| any of 10 terms in text | 1e+04 | per_doc_map | 0.033090 | 1.639 | TRUE |
| count 200 terms (per-term totals) | 1e+04 | loop_count | 0.400800 | 1.146 | TRUE |
| count 200 terms (per-term totals) | 1e+04 | one_collapsed_text | 0.349900 | 1.000 | TRUE |
| replace 200-term dictionary | 1e+04 | loop | 0.418600 | 1.089 | TRUE |
| replace 200-term dictionary | 1e+04 | vectorize_all_FALSE | 0.384200 | 1.000 | TRUE |
| replace 200-term dictionary | 1e+04 | purrr_reduce | 0.417000 | 1.085 | TRUE |
| replace 200-term dictionary | 1e+04 | base_gsub_fixed_loop | 0.418100 | 1.088 | TRUE |
| any of 10 terms in text | 1e+05 | map_str_detect | 0.225400 | 1.054 | TRUE |
| any of 10 terms in text | 1e+05 | map_stri_fixed | 0.224500 | 1.050 | TRUE |
| any of 10 terms in text | 1e+05 | stri_fixed_outer | 0.245000 | 1.146 | TRUE |
| any of 10 terms in text | 1e+05 | stri_fixed_outer_loop | 0.213800 | 1.000 | TRUE |
| any of 10 terms in text | 1e+05 | alternation_regex | 0.907300 | 4.244 | TRUE |
| any of 10 terms in text | 1e+05 | base_grepl_fixed_loop | 0.231300 | 1.082 | TRUE |
| any of 10 terms in text | 1e+05 | per_doc_map | 0.350300 | 1.639 | TRUE |
| count 200 terms (per-term totals) | 1e+05 | loop_count | 4.500000 | 1.287 | TRUE |
| count 200 terms (per-term totals) | 1e+05 | one_collapsed_text | 3.497000 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `vectorize/b6_text_tricks.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 56 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| G1 fixed prefilter, rare literal (hit ~1%) | 1e+04 | regex_only | 1.33600 | 6.407 | TRUE |
| G1 fixed prefilter, rare literal (hit ~1%) | 1e+04 | fixed_prefilter | 0.20850 | 1.000 | TRUE |
| G1 fixed prefilter, common literal (hit ~50-90%) | 1e+04 | regex_only | 1.70700 | 1.037 | TRUE |
| G1 fixed prefilter, common literal (hit ~50-90%) | 1e+04 | fixed_prefilter | 1.64600 | 1.000 | TRUE |
| G2 windowed regex anchored on rare token | 1e+04 | full_regex | 1.32500 | 6.011 | TRUE |
| G2 windowed regex anchored on rare token | 1e+04 | windowed | 0.22040 | 1.000 | TRUE |
| G4 lowercase once vs case_insensitive per term | 1e+04 | fixed_case_insensitive | 5.68000 | 6.919 | TRUE |
| G4 lowercase once vs case_insensitive per term | 1e+04 | lowercase_once | 0.82090 | 1.000 | FALSE |
| G4 lowercase once vs case_insensitive per term | 1e+04 | lowercase_once_base_tolower | 0.99550 | 1.213 | FALSE |
| G4 lowercase once vs case_insensitive per term | 1e+04 | regex_case_insensitive | 5.88400 | 7.168 | TRUE |
| G1 fixed prefilter, rare literal (hit ~1%) | 1e+05 | regex_only | 13.27000 | 6.257 | TRUE |
| G1 fixed prefilter, rare literal (hit ~1%) | 1e+05 | fixed_prefilter | 2.12000 | 1.000 | TRUE |
| G1 fixed prefilter, common literal (hit ~50-90%) | 1e+05 | regex_only | 17.08000 | 1.035 | TRUE |
| G1 fixed prefilter, common literal (hit ~50-90%) | 1e+05 | fixed_prefilter | 16.51000 | 1.000 | TRUE |
| G2 windowed regex anchored on rare token | 1e+05 | full_regex | 13.33000 | 5.755 | TRUE |
| G2 windowed regex anchored on rare token | 1e+05 | windowed | 2.31600 | 1.000 | FALSE |
| G4 lowercase once vs case_insensitive per term | 1e+05 | fixed_case_insensitive | 57.05000 | 6.899 | TRUE |
| G4 lowercase once vs case_insensitive per term | 1e+05 | lowercase_once | 8.26900 | 1.000 | FALSE |
| G4 lowercase once vs case_insensitive per term | 1e+05 | lowercase_once_base_tolower | 10.19000 | 1.232 | FALSE |
| G4 lowercase once vs case_insensitive per term | 1e+05 | regex_case_insensitive | 58.98000 | 7.132 | TRUE |
| G5 unique-then-match, dup rate 10% stri_trans_general | 1e+05 | direct | 0.98420 | 1.062 | TRUE |
| G5 unique-then-match, dup rate 10% stri_trans_general | 1e+05 | unique_match | 0.92650 | 1.000 | TRUE |
| G5 unique-then-match, dup rate 10% R-level per-string fn | 1e+05 | direct | 0.70360 | 1.074 | TRUE |
| G5 unique-then-match, dup rate 10% R-level per-string fn | 1e+05 | unique_match | 0.65530 | 1.000 | TRUE |
| G5 unique-then-match, dup rate 50% stri_trans_general | 1e+05 | direct | 1.05100 | 2.047 | TRUE |
| G5 unique-then-match, dup rate 50% stri_trans_general | 1e+05 | unique_match | 0.51350 | 1.000 | TRUE |
| G5 unique-then-match, dup rate 50% R-level per-string fn | 1e+05 | direct | 0.67070 | 1.936 | TRUE |
| G5 unique-then-match, dup rate 50% R-level per-string fn | 1e+05 | unique_match | 0.34650 | 1.000 | TRUE |
| G5 unique-then-match, dup rate 90% stri_trans_general | 1e+05 | direct | 0.96910 | 8.977 | TRUE |
| G5 unique-then-match, dup rate 90% stri_trans_general | 1e+05 | unique_match | 0.10800 | 1.000 | TRUE |
| G5 unique-then-match, dup rate 90% R-level per-string fn | 1e+05 | direct | 0.64440 | 8.710 | TRUE |
| G5 unique-then-match, dup rate 90% R-level per-string fn | 1e+05 | unique_match | 0.07399 | 1.000 | TRUE |
| G6 remove punct+digits: charclass vs regex | 1e+04 | regex | 0.14520 | 2.459 | TRUE |
| G6 remove punct+digits: charclass vs regex | 1e+04 | charclass | 0.05905 | 1.000 | TRUE |
| G6 remove punct+digits: charclass vs regex | 1e+04 | regex_posix | 0.18400 | 3.115 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 1e+04 | regex | 0.11550 | 3.933 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 1e+04 | fixed | 0.02937 | 1.000 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 1e+04 | charclass | 0.04880 | 1.662 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 1e+04 | base_gsub | 0.04464 | 1.520 | TRUE |
| G6 collapse whitespace runs: charclass vs regex | 1e+04 | regex | 0.24260 | 3.072 | TRUE |
| G6 collapse whitespace runs: charclass vs regex | 1e+04 | regex_trim | 0.17120 | 2.168 | TRUE |
| G6 collapse whitespace runs: charclass vs regex | 1e+04 | charclass_merge | 0.07896 | 1.000 | TRUE |
| G9 to_ascii: fixed table first, trans only on remaining | 1e+04 | trans_general_all | 3.20300 | 37.400 | TRUE |
| G9 to_ascii: fixed table first, trans only on remaining | 1e+04 | fixed_then_trans_on_remaining | 0.08563 | 1.000 | TRUE |
| G6 remove punct+digits: charclass vs regex | 5e+04 | regex | 0.73060 | 2.438 | TRUE |
| G6 remove punct+digits: charclass vs regex | 5e+04 | charclass | 0.29970 | 1.000 | TRUE |
| G6 remove punct+digits: charclass vs regex | 5e+04 | regex_posix | 0.73330 | 2.447 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 5e+04 | regex | 0.57990 | 3.592 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 5e+04 | fixed | 0.16140 | 1.000 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 5e+04 | charclass | 0.24430 | 1.513 | TRUE |
| G6 remove single char ',': fixed vs charclass vs regex | 5e+04 | base_gsub | 0.22510 | 1.394 | TRUE |
| G6 collapse whitespace runs: charclass vs regex | 5e+04 | regex | 1.20400 | 3.115 | TRUE |
| G6 collapse whitespace runs: charclass vs regex | 5e+04 | regex_trim | 0.90180 | 2.333 | TRUE |
| G6 collapse whitespace runs: charclass vs regex | 5e+04 | charclass_merge | 0.38660 | 1.000 | TRUE |
| G9 to_ascii: fixed table first, trans only on remaining | 5e+04 | trans_general_all | 16.17000 | 37.450 | TRUE |
| G9 to_ascii: fixed table first, trans only on remaining | 5e+04 | fixed_then_trans_on_remaining | 0.43180 | 1.000 | TRUE |

</details>

<details>

<summary>

Source: benchmark results `vectorize/b7_join_cbind.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03) 39 rows
</summary>

| task | n | method | median_s | ratio_to_fastest | identical_to_ref |
|:---|---:|:---|---:|---:|:---|
| combine 5 tables x 1000 keys | 5e+03 | reduce_merge | 0.0013230 | 25.590 | TRUE |
| combine 5 tables x 1000 keys | 5e+03 | reduce_left_join | 0.0019790 | 38.290 | TRUE |
| combine 5 tables x 1000 keys | 5e+03 | reduce_dt_merge | 0.0021830 | 42.230 | TRUE |
| combine 5 tables x 1000 keys | 5e+03 | stack_dcast | 0.0017400 | 33.660 | TRUE |
| combine 5 tables x 1000 keys | 5e+03 | collapse_join | 0.0000517 | 1.000 | TRUE |
| combine 5 tables x 1000 keys | 5e+03 | cbind_cols | 0.0000621 | 1.201 | TRUE |
| combine 5 tables x 1000 keys | 5e+03 | unlist_cols | 0.0001748 | 3.381 | TRUE |
| combine 5 tables x 1000 keys | 5e+03 | vec_cbind | 0.0000567 | 1.096 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | reduce_merge | 0.3966000 | 5745.000 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | reduce_left_join | 0.0343300 | 497.200 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | reduce_dt_merge | 0.0214900 | 311.200 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | stack_dcast | 0.0473200 | 685.400 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | collapse_join | 0.0164400 | 238.100 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | cbind_cols | 0.0000690 | 1.000 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | unlist_cols | 0.0001624 | 2.353 | TRUE |
| combine 5 tables x 100000 keys | 5e+05 | vec_cbind | 0.0000906 | 1.312 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | reduce_merge | 0.0618800 | 340.100 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | reduce_left_join | 0.0170300 | 93.600 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | reduce_dt_merge | 0.0242200 | 133.100 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | stack_dcast | 0.0148000 | 81.340 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | collapse_join | 0.0010100 | 5.551 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | cbind_cols | 0.0001838 | 1.010 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | unlist_cols | 0.0005044 | 2.772 | TRUE |
| combine 20 tables x 10000 keys | 2e+05 | vec_cbind | 0.0001820 | 1.000 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | reduce_merge | 0.0740000 | 95.200 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | reduce_left_join | 0.0611400 | 78.660 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | reduce_dt_merge | 0.0457600 | 58.870 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | stack_dcast | 0.0127200 | 16.360 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | collapse_join | 0.0012360 | 1.590 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | cbind_cols | 0.0007773 | 1.000 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | unlist_cols | 0.0021290 | 2.739 | TRUE |
| combine 100 tables x 1000 keys | 1e+05 | vec_cbind | 0.0008754 | 1.126 | TRUE |
| combine 100 tables x 10000 keys | 1e+06 | reduce_left_join | 0.1145000 | 144.000 | TRUE |
| combine 100 tables x 10000 keys | 1e+06 | reduce_dt_merge | 0.2004000 | 252.000 | TRUE |
| combine 100 tables x 10000 keys | 1e+06 | stack_dcast | 0.0715600 | 89.990 | TRUE |
| combine 100 tables x 10000 keys | 1e+06 | collapse_join | 0.0055830 | 7.022 | TRUE |
| combine 100 tables x 10000 keys | 1e+06 | cbind_cols | 0.0007952 | 1.000 | TRUE |
| combine 100 tables x 10000 keys | 1e+06 | unlist_cols | 0.0022120 | 2.782 | TRUE |
| combine 100 tables x 10000 keys | 1e+06 | vec_cbind | 0.0010150 | 1.276 | TRUE |

</details>
