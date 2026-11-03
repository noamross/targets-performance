# Vectorization: replacing loops, map and apply


**When this matters.** A profile shows time in `lapply`, `purrr::map*`, `sapply`, `apply`, `mapply`, `Reduce` or `do.call(rbind, ...)`, or in many string operations over a long character vector. The fix is to call one function on the whole vector, or to do less work (filter first, compute on unique values). Loops over a few dozen heavy items (model fits, files, API calls) are fine; leave them.

## Loop and apply patterns

| Replace | With | n | Speedup |
|:---|:---|:---|:---|
| `do.call(rbind, dfs)`, 1000 pieces | `collapse::rowbind(dfs)` | 1e4 | 55x |
| `Reduce(rbind, dfs)`, 1000 pieces | `collapse::rowbind(dfs)` | 1e4 | 441x |
| `do.call(rbind, dfs)`, 1000 pieces | `data.table::rbindlist(dfs)` | 1e4 | 31x |
| `do.call(rbind, dfs)`, 1000 pieces | `purrr::list_rbind(dfs)` | 1e4 | 8.1x |
| `vctrs::vec_rbind(!!!dfs)`, 10000 pieces | `purrr::list_rbind(dfs)` | 1e5 | 36x |
| `split()` + `lapply(mean)`, 1e5 groups | `collapse::fmean(x, g)` | 1e6 | 50x |
| dplyr `.by` mean, 1e5 groups | `collapse::fmean(x, g)` | 1e6 | 50x |
| `split()` + `lapply(mean)`, 1e5 groups | `rowsum(x, g) / tabulate(g)` | 1e6 | 3.8x |
| `sapply(x, \(v) if (v > .5) v*2 else v+1)` | `ifelse(x > .5, x*2, x+1)` | 1e6 | 14x |
| same | `data.table::fifelse(...)` | 1e6 | 82x |
| `map_dbl(x, sqrt)` | `sqrt(x)` | 1e6 | 67x |
| `apply(m, 1, mean)` | `rowMeans(m)` | 1e6 | 687x |
| `apply(m, 1, var)` | `Rfast::rowVars(m)` | 1e6 | 286x |
| `mapply(min, a, b)` | `pmin(a, b)` | 1e5 | 155x |
| `map2_dbl(a, b, min)` | `pmin(a, b)` | 1e6 | 46x |
| `do.call(c, list_of_scalars)` | `unlist(l, use.names = FALSE)` | 1e6 | 5.6x |
| `sapply(x, switch, ...)` recode | `new[match(x, old)]` | 1e6 | 18x |
| `case_when()` recode | `new[match(x, old)]` | 1e6 | 1.9x |
| `Reduce(merge, 20 tables)` | `Reduce(collapse::join, tables)` | 2e5 | 61x |
| `Reduce(merge, 20 tables)` | stack + `data.table::dcast` | 2e5 | 4.2x |

Source: benchmark results `vectorize/b1_rbind.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-02, 2026-11-03); `vectorize/b2_groups.csv`, `vectorize/b3_elementwise.csv`, `vectorize/b4_pairs.csv`, `vectorize/b7_join_cbind.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

What the table says:

- **Row-binding is never worth looping.** No shape tested (5 to 10,000 pieces, 1e3 to 5e6 rows) made `do.call(rbind)` competitive. `Reduce(rbind)` is quadratic: each step copies everything so far. Spreading thousands of pieces as arguments (`vec_rbind(!!!l)`) is also slow; pass the list.
- **Grouped statistics:** use a grouped function, not split-apply-combine. At tiny sizes (1e3 rows) dplyr `.by` (814 µs) and data.table `by` (292 µs) lose even to `split()` + `lapply` (49 µs), because of their fixed setup; collapse and `rowsum` win at every size.
- **`apply(m, 1, f)` is a loop.** It only gains when a dedicated row function exists (`rowSums`, `rowMeans`, `Rfast::rowVars`, `matrixStats`). `collapse::fmean(t(m))` pays for the transpose (6.9x slower than `rowMeans`).
- **`Vectorize()` and `mapply()` are not vectorization**; they loop in R.
- **Keys already aligned?** `cbind` the columns (795 µs for 100 tables), but only after `stopifnot(identical(a$id, b$id))`; otherwise a join is required.

## Text: what does and does not help

Many "vectorized" string idioms just move the same loop into C. With fixed (literal) patterns, a plain loop over terms is already near the floor:

| approach                                | time vs reference |
|:----------------------------------------|:------------------|
| loop of `stri_detect_fixed` (reference) | 1.0x              |
| `stringr::str_detect(fixed())` loop     | 1.0x              |
| base `grepl(fixed = TRUE)` loop         | 1.0x              |
| outer product (`rep()` docs x terms)    | 1.1x              |
| one alternation regex `a\|b\|c`         | 4.0x              |
| per-document `vapply`                   | 1.6x              |

Source: benchmark results `vectorize/b5_text.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03). 1e5 documents of about 300 characters; values above 1 are slower.

- `stri_replace_all_fixed(x, pats, reps, vectorize_all = FALSE)` was only 1.1x faster than a loop for a 200-term dictionary. It applies replacements in sequence, so an earlier replacement can create a match for a later pattern, as in a loop.
- Literal matching (`stri_*_fixed`) beats regex for literals; character classes (`stri_replace_all_charclass`) beat regex for one-character classes: removing punctuation and digits 2.4x, collapsing whitespace runs 3.1x, a single literal character via `fixed` 3.6x. All identical.

The real wins skip work. Each trick below was measured on synthetic text (Zipf vocabulary, mixed case, some non-ASCII words) and checked with `identical()`:

| trick | n | speedup | identical | exact |
|:---|:---|:---|:---|:---|
| fixed-string prefilter before regex, literal in ~1% of docs | 1e5 | 6.3x | TRUE | by construction |
| same, literal in 50-90% of docs | 1e5 | 1.0x | TRUE | by construction (no gain) |
| regex only in a window around each literal hit | 1e4 | 6.0x | TRUE | no: see trap |
| same, larger corpus | 1e5 | 5.8x | FALSE | no: see trap |
| lowercase once, then case-sensitive fixed search | 1e5 | 6.9x | FALSE | ASCII terms only |
| expensive per-string function on unique values, 90% duplicates | 1e5 | 9.0x | TRUE | yes, if pure |
| same, 50% duplicates | 1e5 | 2.0x | TRUE | yes, if pure |
| same, 10% duplicates | 1e5 | 1.1x | TRUE | yes, if pure |
| fixed replacement table, transliterate only still-non-ASCII docs | 5e4 | 37x | TRUE | only if table agrees with transliterator |

Source: benchmark results `vectorize/b6_text_tricks.csv` (Darwin arm64, 12 cores, R 4.6.2; run 2026-11-03).

Patterns, in code:

``` r
# prefilter: the literal must occur in any match of the regex
hit <- stringi::stri_detect_fixed(text, literal)
hit[hit] <- stringi::stri_detect_regex(text[hit], pattern)

# compute once per distinct value
u <- unique(x)
y <- f(u)[match(x, u)]

# lowercase once (exact only for ASCII terms)
low <- stringi::stri_trans_tolower(text)
counts <- vapply(terms_lower, \(t) sum(stringi::stri_count_fixed(low, t)), numeric(1))
```

When each pays:

- **Prefilter** pays only when few documents contain the literal. When most do, you pay for the fixed search and still run the regex everywhere.
- **Unique-then-match** breaks even near 10% duplicates; the speedup tracks 1 / (1 - duplicate share). It needs a pure, element-wise function.
- **Compute once, share**: if several targets derive the same thing from a big input, make one target that computes it for the union of keys and let consumers look it up with `match()` (guard with `stopifnot(!anyNA(i))`). Consumers then no longer depend on, or load, the big input. See `case-study.md`.

## Traps

- **Windowed regex is not exact.** Identical at 1e4 documents, not at 1e5: a window that starts at the literal invents a word boundary when the literal sits inside a longer word, and matches longer than the window are lost. Start the window a few characters earlier, re-check the boundary character, and fall back to the full text when a match touches the window edge.
- **Lowercasing once is not Unicode case folding.** `stri_trans_tolower()` maps a word-final Greek Σ to ς, so lowercase-then-fixed differs from `case_insensitive = TRUE` for such terms; base `tolower()` differs elsewhere. Ligatures such as "ﬁ" match case-insensitive regex but not case-insensitive fixed search. Exact for ASCII terms; for other text, normalize to ASCII upstream (an intended output change) or keep the old path for non-ASCII documents.
- Transliteration tables: map soft hyphens and zero-width spaces to the empty string `""`, not a space `" "`. Full `"Any-Latin; Latin-ASCII"` can change meaning (`"µm"` becomes `"mm"`); run NFKC first and transliterate only what the fixed table leaves.
- Merging many regexes into one alternation was slower and not identical (overlapping matches) in the case study.
- `fifelse`/`fcase` evaluate every branch; `ifelse` and `kit::nif` do not.
- `tabulate()` drops values ≤ 0; `rowsum()` sorts groups; `rbindlist()` binds by position after a name-mismatch warning (`use.names = "check"`); comparisons need row names reset and the same class.
- `purrr::in_parallel()` / `mirai_map()` inside a target that already runs on a crew worker nests parallelism; see `parallelism.md`.
