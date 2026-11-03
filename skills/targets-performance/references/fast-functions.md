# Fast replacement functions


**When this matters.** A profile shows one target spending its time in grouped summaries, sorting, counting, joins or row/column statistics on large vectors (≥ 1e5 rows), or the same small operation called thousands of times. Swapping in collapse, data.table, kit or Rfast is often the cheapest big win, but every swap can change the output in small ways, so each one needs an identity check.

## How to read the numbers

Speedup = time of the usual call / time of the replacement, same input, one thread unless stated, median of several runs. They come from the `fastfns` benchmarks on one machine (see the source lines and `benchmarks.md`); use them as ratios, not absolute times. Re-measure on your data with `bench::mark()` before adopting.

Two effects drive the gains:

- **Per-call overhead.** dplyr `.by` and data.table `[, by =]` cost a fixed fraction of a millisecond per call regardless of size: at 1e3 rows a grouped sum took 816 µs in dplyr, 265 µs in data.table and 10 µs in collapse. Code that runs a small summary inside a loop or a branch pays this many times.
- **Algorithms.** Radix sorting, hashing and precomputed groupings scale better: collapse with a reused grouping object (`GRP()`) summed 1e7 values over 1e6 groups 210x faster than dplyr.

Where base R is already optimal, swaps gain nothing: `rowSums()`/`rowMeans()` matched Rfast (1.0x), and base `order()` on numbers is already radix (Rfast `Order` was 0.04x of base speed, i.e. slower).

## Swap table

| Replace | With | n | Speedup | Trap |
|:---|:---|:---|:---|:---|
| grouped sum, 10 groups (`rowsum`) | `collapse::fsum(x, g)` | 1e7 | 5.5x | na.rm = TRUE default |
| same, grouping reused | `g <- GRP(key); fsum(x, g)` | 1e7 | 11x | build GRP once, reuse across stats |
| grouped sum, 1e6 groups (dplyr) | `fsum(x, GRP(key))` | 1e7 | 210x | groups sorted, not appearance order |
| grouped mean, 1e6 groups (`tapply`) | `collapse::fmean(x, g)` | 1e7 | 31x | last-bit differences: use all.equal |
| grouped median, 1e6 groups (dplyr) | `collapse::fmedian(x, g)` | 1e7 | 48x |  |
| same (dplyr) | data.table GForce (its built-in C grouped stats) `DT[, median(x), by = g]` | 1e7 | 23x | GForce only for a bare call in j |
| grouped 90% quantile, chr key (`tapply`) | `fnth(x, 0.9, GRP(key))` | 1e7 | 7.2x | not bit-identical |
| `apply(m, 2, var)` | `Rfast::colVars(m)` | 1e7 | 5.5x | matrix only; no NA handling |
| `apply(m, 1, median)` | `Rfast::rowMedians(m)` | 1e7 | 24x | not identical; all.equal |
| `colSums(m)` | `collapse::fsum(m)` | 1e7 | 4.7x | drops names unless asked |
| `order(chr)` (locale) | `order(x, method = "radix")` | 2e6 | 198x | **C-locale order differs** |
| `unique(int)` | `collapse::funique` / `kit::funique` | 1e7 | 3.3x | same first-appearance order |
| `duplicated(chr)` | `collapse::fduplicated` | 2e6 | 6.0x |  |
| `match(dbl)` | `collapse::fmatch` | 1e7 | 3.2x | `Rfast::Match` is not a drop-in |
| `table(dbl)` | `collapse::fcount` | 1e7 | 107x | returns a data frame, not a table |
| `table(chr)` | `kit::countOccur` | 2e6 | 42x | returns a data frame |
| `left_join` m:1 (dplyr) | `collapse::join(x, y)` | 2e6 | 7.6x | **first match only by default** |
| same (dplyr) | data.table `y[x, on = ]` | 2e6 | 3.4x | column order, class differ |
| `ifelse()` | `kit::iif` / `data.table::fifelse` | 1e7 | 13x | strict types; keeps attributes |
| nested `ifelse`, 3 cases | `kit::nif` / `fcase` / `case_when` | 1e7 | 5.7x | fcase evaluates every branch |
| grouped lag (`ave`) | `collapse::flag(x, g = g)` | 1e7 | 69x | name `g =`; needs sorted data or `t =` |
| grouped cumsum (`ave`) | `collapse::fcumsum(x, g)` | 1e7 | 42x | skips NA instead of propagating |

Source: benchmark results `fastfns/b1_grouped.csv`, `fastfns/b2_matrix.csv`, `fastfns/b3_sortuniq.csv`, `fastfns/b4_join.csv`, `fastfns/b4_ifelse_lag.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

Small inputs: at 1e3 rows collapse beat dplyr by 143x on a grouped mean and `kit::countOccur` beat `table()` by 20x, while data.table's `unique()` was slower than base (0.09x of base speed). For small data called often, collapse and kit win; data.table and dplyr pay their per-call setup.

**fastverse and Rfast2.** The `fastverse` meta-package installs and attaches data.table, collapse, kit and magrittr[^1]; `fastverse_conflicts()` lists masked functions, and attaching it does not turn on collapse masking[^2]. In a pipeline, list the packages you use in `tar_option_set(packages = )` instead, so workers load only those. Rfast2 adds functions beyond Rfast, such as `colGroup()` for grouped column statistics on a matrix; its group index must be consecutive integers from 1, or it crashes[^3].

## Threads

Several of these functions can run multithreaded. Speedup from 1 to k threads at 1e7 elements:

| task                      | macOS 4 | macOS 8 | Linux 4 | Linux 6 |
|:--------------------------|:--------|:--------|:--------|:--------|
| DT_groupby_sum            | 2.1x    | 2.2x    | 2.2x    | 2.6x    |
| DT_forder_dbl             | 1.6x    | 1.7x    | 1.6x    | 1.8x    |
| DT_forder_int             | 3.3x    | 4.6x    | 3.5x    | 4.9x    |
| DT_uniqueN_int            | 3.2x    | 3.1x    | 3.5x    | 4.9x    |
| collapse_fsum_matrix_cols | 3.3x    | 2.9x    | 3.1x    | 3.1x    |
| collapse_fsum_grouped_vec | 1.0x    | 1.0x    | 1.0x    | 1.0x    |
| collapse_fmedian_grouped  | 2.0x    | 2.3x    | 1.8x    | 2.0x    |
| collapse_fnth90_grouped   | 1.9x    | 2.2x    | 1.7x    | 1.8x    |
| kit_iif                   | 2.0x    | 2.1x    | 3.8x    | 5.7x    |
| kit_psort_dbl             | 1.0x    | 1.0x    | 1.0x    | 1.0x    |
| Rfast_colMedians          | 3.8x    | 6.5x    | 3.9x    | 5.3x    |
| Rfast_colVars             | 3.6x    | 4.6x    | 3.3x    | 4.4x    |

Source: benchmark results `fastfns/b6_threads.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03); `fastfns/b6_threads_linux.csv` (Linux aarch64, 12 cores, R 4.6.2; run 2026-11-03). Linux = ARM64 container limited to 6 CPUs.

- data.table defaults to half the logical CPUs; collapse, kit and qs2 default to 1 thread; Rfast threads only with `parallel = TRUE` (`cores = 0` means all cores).
- kit uses OpenMP only where it was built with it: the macOS CRAN build prints "OPENMP disabled", the Linux build "OPENMP enabled using 1 thread". `kit::iif(nThread =)` scales on Linux only; the one-step drop on macOS is not threading (OpenMP is off there, and the time stays flat from 2 to 8 threads). `machine_profile.R` reports which build you have.
- Not every function threads: `collapse::fsum(x, g)` on a grouped vector and `kit::psort` did not scale on either OS.
- Threads compete with pipeline workers. See `parallelism.md` before turning them on inside parallel targets.

## Identity traps

Check every swap with `identical(old, new)` on real data; fall back to `all.equal()` only when you accept floating-point differences, and say so.

1.  **Means and quantiles are not bit-identical.** `fmean(x)` vs `mean(x)`: 0/20 identical; all.equal 20/20 (20 seeds). Grouped sums and medians matched exactly; grouped means did not (collapse, data.table GForce, Rfast). Regression checks need a tolerance for these.
2.  **`na.rm = TRUE` is collapse's default.** `fsum(c(NA, 1))` returns 1 where `sum()` gives NA; an all-NA group gives NA in `fmean` but NaN in base; `fcumsum(c(1, NA, 3))` gives `1, NA, 4`. Set `set_collapse(na.rm = FALSE)` to match base.
3.  **Character order.** Every radix tool (`order(method = "radix")`, data.table, collapse, dplyr's `arrange()`) sorts in the C locale: uppercase before lowercase, accents last. Base `order()` uses the session locale. Group order, sorted joins and "keep the first row" logic change.
4.  **Joins.** With duplicate keys in `y`, `collapse::join()` keeps the first match only: 2,000,000 rows where dplyr returns 2,009,091 (no warning). Pass `multiple = TRUE`. data.table errors unless `allow.cartesian = TRUE`.
5.  **Types and classes.** `kit::iif(TRUE, 1L, 2)` errors on the integer/double mix; `fifelse` keeps `Date` where `ifelse` drops it; count functions return data frames, not `table`s; grouped integer `fsum` errors on overflow.
6.  **Random numbers.** `Rfast::Rnorm` ignores `set.seed()`; keep base RNG for seeded work.
7.  **Masking.** `set_collapse(mask = "all")` replaces dplyr verbs by collapse ones. Afterwards an unqualified `summarise(d, s = sum(x), .by = g)` ignores `.by` and returns the grand total on every row; `dplyr::summarise` still groups but `sum()` now skips NA. Never mask `"all"` or `"manip"` in a pipeline that uses dplyr; call `collapse::` functions explicitly.

## How to check a swap

``` r
old <- targets::tar_read(input) |> old_fun()
new <- targets::tar_read(input) |> new_fun()
identical(old, new)          # required for exact swaps
all.equal(old, new)          # only when last-bit differences are acceptable
bench::mark(old_fun(x), new_fun(x), check = FALSE, iterations = 10)
```

## Traps

- `data.table::forder` is not exported (use `setorder()` or `order(method = "radix")`); collapse has no `%fin%` (use `fmatch(x, table, 0L) > 0L`).
- `flag(x, g)`: the second positional argument is the lag count, not the group. Name it.
- `DT[, lapply(.SD, fmean), by = g]` calls a collapse function per group and loses both speedups; use plain `mean` (GForce) or collapse on the whole column.
- data.table's thread default ignores container CPU limits (see `environment.md`).

[^1]: Source: <https://fastverse.org/fastverse/articles/fastverse_intro.html> (retrieved 2026-11-02; The fastverse installs 4 core packages (data.table, collapse, kit and magrittr)).

[^2]: Source: <https://fastverse.org/fastverse/articles/fastverse_intro.html> (retrieved 2026-11-02; keep track of the search path with fastverse_conflicts()).

[^3]: Source: <https://cran.r-project.org/web/packages/Rfast2/Rfast2.pdf> (retrieved 2026-11-02; Do not put 1, 3, 4 as this will cause C++ to crash.).
