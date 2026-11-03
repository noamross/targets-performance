# Environment: BLAS, OpenMP builds, versions and start-up


**When this matters.** Targets spend their time in linear algebra (regressions on wide model matrices, `crossprod`, matrix factorizations, GAMs, mixed models), in packages that may or may not have been built with OpenMP, or in starting R workers. These are machine and installation settings, not pipeline code. Changing them needs the user's approval: it affects every project that uses that R installation, and it can change numerical results.

## Which BLAS R uses

`sessionInfo()` (or `machine_profile.R`) names the BLAS and LAPACK libraries. What the common installers ship:

- **Windows** (CRAN installer): R's reference BLAS. Optimized BLAS needs a replacement `Rblas.dll` (e.g. OpenBLAS or MKL builds); not tested here.
- **macOS** (CRAN installer): reference BLAS, with Apple's Accelerate shipped alongside and selectable.
- **Linux**: whatever the distribution's BLAS alternative points to; many builds (e.g. rocker images) use OpenBLAS (section below).

The CI runs (`benchmarks.md`, cross-platform section) time `blas/blas.R` under each runner's BLAS. A local macOS machine, same code, reference BLAS vs Accelerate:

| operation | reference | Accelerate | speedup | max relative difference |
|:---|:---|:---|:---|:---|
| `crossprod(A)` 2000² | 4.1 s | 23 ms | 176x | 4e-15 |
| `A %*% A` 2000² | 2.2 s | 45 ms | 48x | 4e-15 |
| `solve()` 2000² | 2.5 s | 140 ms | 18x | 3e-13 |
| `chol()` 2000² | 1.3 s | 14 ms | 93x | 2e-14 |
| `svd()` 1000² | 1.9 s | 136 ms | 14x | 1e-14 |
| `qr()` 2000² | 3.1 s | 2.0 s | 1.5x | 3e-16 |
| `.lm.fit()` 2e5 x 51 | 381 ms | 152 ms | 2.5x | 2e-14 |
| `glm.fit()` logit 2e5 x 51 | 3.7 s | 1.7 s | 2.2x | 2e-14 |

Source: benchmark results `blas/blas.csv`, `blas/blas_diffs.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). Relative difference = largest absolute difference in the results (ignoring sign, which factorizations may flip) / largest absolute value.

- Matrix products and factorizations gain the most. `qr()` gains little because R's default `qr()` uses LINPACK (`dqrdc2`), which calls only level-1 (vector) BLAS; `qr(x, LAPACK = TRUE)` uses LAPACK instead (not measured here). `lm()` and `glm()` gain less than raw products because they do more than BLAS work.
- **Results change in the last bits.** `identical()` regression checks fail after a switch; use `all.equal()` with a stated tolerance, and re-snapshot (`tar_snapshot.R`) after switching, not across the switch.
- The setting applies to the whole R installation (every project on that R version) and usually needs admin rights. macOS: the R for macOS FAQ describes switching to `libRblas.vecLib.dylib`; [rig](https://github.com/r-lib/rig) wraps it (`rig system blas set accelerate <version>`). Linux: `update-alternatives` (below). Windows: replace `Rblas.dll` in R's `bin\x64` with an optimized build, keeping the original to undo.
- Predict the payoff before suggesting it: profile (`profile_pipeline.R`) and check the share of time in `%*%`, `crossprod`, `solve`, `chol`, `La_*`, `lm.fit`, `glm.fit`. If it is small, skip it.

## BLAS on Linux

Many Linux R builds (e.g. the rocker images) already link OpenBLAS. Which variant matters:

| setup | `crossprod(A)` 2000² | `solve()` 2000² | `svd()` 1000² | `.lm.fit()` 2e5 x 51 | `glm.fit()` logit 2e5 x 51 |
|:---|:---|:---|:---|:---|:---|
| reference BLAS | 3.8 s | 2.5 s | 1.9 s | 374 ms | 3.8 s |
| OpenBLAS serial | 145 ms | 421 ms | 327 ms | 153 ms | 1.7 s |
| OpenBLAS pthread, 1 thread | 145 ms | 424 ms | 327 ms | 154 ms | 1.7 s |
| OpenBLAS pthread, 6 threads | 30 ms | 91 ms | 185 ms | 89 ms | 1.1 s |
| OpenBLAS pthread, unset (host CPUs) | 91 ms | 1.4 s | 556 ms | 206 ms | 2.0 s |
| OpenBLAS OpenMP, `OMP_NUM_THREADS=6` | 30 ms | 93 ms | 219 ms | 88 ms | 1.2 s |
| OpenBLAS OpenMP, unset (host CPUs) | 78 ms | 132 ms | 464 ms | 877 ms | 8.1 s |

Source: benchmark results `blas/blas_linux.csv` (Linux aarch64, 12 cores, R 4.6.2; run 2026-11-03). ARM64 Linux container with a CPU quota below the host's CPU count (`benchmarks.md`).

- Any OpenBLAS beats reference BLAS by a wide margin, even single-threaded.

- **Thread defaults are the trap.** Unset, OpenBLAS starts one thread per *host* CPU, ignoring the container's CPU limit, and was slower than a single thread on some operations. With parallel workers it is far worse (`parallelism.md`).

- Variables: the pthread build reads `OPENBLAS_NUM_THREADS` (falls back to `OMP_NUM_THREADS`); the OpenMP build reads only `OMP_NUM_THREADS`; the serial build ignores both. Set both. At run time use `RhpcBLASctl::blas_set_num_threads()` (pthread) or `RhpcBLASctl::omp_set_num_threads()` (OpenMP).

- Find the real library: `sessionInfo()` shows the `libblas.so.3` symlink. `machine_profile.R` reads `/proc/self/maps`; the directory (`openblas-pthread`, `openblas-openmp`, `openblas-serial`) names the variant.

- Switching on Debian/Ubuntu needs root and `update-alternatives --set` on three alternatives: `libblas.so.3-<arch>-linux-gnu`, `liblapack.so.3-<arch>-linux-gnu` and `libopenblas.so.0-<arch>-linux-gnu` (`<arch>` is `x86_64` or `aarch64`). For example, for the pthread variant:

  ``` sh
  a=/usr/lib/aarch64-linux-gnu
  sudo update-alternatives --set libblas.so.3-aarch64-linux-gnu $a/openblas-pthread/libblas.so.3
  sudo update-alternatives --set libopenblas.so.0-aarch64-linux-gnu $a/openblas-pthread/libopenblas.so.0
  sudo update-alternatives --set liblapack.so.3-aarch64-linux-gnu $a/openblas-pthread/liblapack.so.3
  # interactive: sudo update-alternatives --config libblas.so.3-aarch64-linux-gnu
  ```

  Switching only `libblas.so.3` gave the wrong variant or a `symbol lookup error`. Verify afterwards in `/proc/self/maps`.

- Avoid the OpenMP variant if code forks (`parallel::mclapply()`): forked children hung on BLAS after the parent had used OpenMP. The pthread variant did not.

- MKL: x86-64 only; not tested here.

## OpenMP builds of packages

Several packages thread with OpenMP only if they were compiled with it:

- data.table: OpenMP on the macOS CRAN binary and on Linux in these tests.
- kit: the macOS CRAN binary had OpenMP disabled; the Linux build had it (default 1 thread). Only matters for `iif`, `nif`, `vswitch`.
- fst: its macOS binary failed to load on the local test machine (missing OpenMP runtime symbol).

OpenMP support depends on the OS, the binary and the compiler it was built with (the CI runners' machine profiles show it per platform), so check rather than assume: `machine_profile.R` reports each. Building from source with OpenMP on macOS needs a separate OpenMP runtime and compiler flags; suggest it only when a profiled hot spot uses one of these functions on large data.

## Versions

- **targets.** Large pipelines got much faster up-to-date checks in targets 1.10 (413.16 s to 35.538 s on a published benchmark[^1]) and later; the first run after upgrading from \< 1.10 is slow once (timestamp conversion).
- **duckdb ≥ 2.0** adds asynchronous I/O for remote parquet and DuckLake 1.1 support (`remote-data.md`). The in-memory cache for remote files is older (on by default since 1.3.0[^2]), so it is a reason to upgrade only from duckdb \< 1.3.0. For async I/O, a published S3 benchmark went from 8.23 s to 2.844 s[^3]. Upgrading changes a dependency: ask, and check the lock file.
- **R** itself: newer R versions change BLAS defaults and APIs (one GitHub-only package needed a patch to build on R 4.6). Upgrade deliberately, never in passing.
- `check_versions.R` compares installed versions with those the skill's benchmarks used and flags major/minor differences.

## Start-up: `.Rprofile`, renv and packages

Every worker runs the project `.Rprofile` and then loads the pipeline's packages (`parallelism.md`). Typical costs, from fresh `Rscript` processes:

| package    | attach time |
|:-----------|:------------|
| targets    | 252 ms      |
| crew       | 231 ms      |
| dplyr      | 145 ms      |
| arrow      | 171 ms      |
| duckdb     | 193 ms      |
| data.table | 28 ms       |
| collapse   | 54 ms       |
| qs2        | 49 ms       |

Source: benchmark results `startup/pkg_load_time.csv` (R 4.6.2; run 2026-11-03). Bare `Rscript`: 144 ms. Elsewhere, tidyverse took 533 ms and ggplot2 315 ms[^4].

renv projects pay more. In a small test project, R start-up averaged 800 ms with default renv, 480 ms with the synchronization check off and 330 ms without renv[^5].

``` r
# .Rprofile
options(renv.config.synchronized.check = FALSE)   # before activate.R: skip the status check at start
source("renv/activate.R")
if (interactive() && !nzchar(Sys.getenv("TAR_ACTIVE"))) {
  # status checks, dev packages, messages: interactive sessions only
}
```

Workers and `tar_make()`'s background process are never interactive, so `interactive()` alone already excludes them; `TAR_ACTIVE` also covers an interactive `tar_make(callr_function = NULL)`. Keep the renv autoloader on (workers need the project library). Definitions can stay outside the guard; calls and attaches go inside. `startup_cost.R` measures all of this for a project.

## Traps

- Switching BLAS breaks bit-identical regression checks and changes every project on that R version.
- A container's CPU limit is invisible to `detectCores()`, data.table, OpenBLAS and arrow; duckdb respects it.
- Project library tools (renv, `rig proj sync`) can prune packages installed outside the lock file; record any off-manifest install.
- Never install, upgrade or switch BLAS without the user's approval.

[^1]: Source: <https://raw.githubusercontent.com/ropensci/targets/main/NEWS.md> (retrieved 2026-11-02; after).

[^2]: Source: <https://duckdb.org/2025/05/21/announcing-duckdb-130.html> (retrieved 2026-11-03; New Features \> External File Cache: "With this release, we added a cache for data from external files." ... "The cache is enabled by default").

[^3]: Source: <https://duckdb.org/2026/07/31/asynchronous-io.html> (retrieved 2026-11-02; mean runtime v2.0.0-dev).

[^4]: Source: local plain Rscript (user lib) (retrieved 2026-11-03; library(tidyverse)).

[^5]: Source: benchmark `startup/renv_startup.sh` in the skill's source repository (`benchmarks.md`) (retrieved 2026-11-03; mean of 10 Rscript -e 1 in 17-pkg renv project).
