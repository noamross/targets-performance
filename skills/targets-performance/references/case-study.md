# Case study: a text-analysis pipeline


**When this matters.** As a worked example of the whole method on a real pipeline: what was measured, which rewrites paid, which did not, and what went wrong. The pipeline counted terms and changes across about 412k documents; its main table was about 1.1 GB in memory, on a laptop with 36 GB of RAM. Numbers below come from the pipeline author's report[^1]; they are single measurements on that machine.

## Result

| State | Time | Outputs |
|----|----|----|
| Before: serial, `memory = "transient"` | 736 s summed (about 12 min wall) | reference |
| After the changes below, 8 crew workers, shared memory for the big table | 316 s wall, 571 s summed | 14 intermediate targets identical; 44 of 45 output files byte-identical (the other embeds its save time) |

With workers, wall time approached the slowest dependency chain, which ended in a plot taking 208 s that could not be sped up without changing the output. `tar_dag.R` reports exactly this bound (critical path).

## Method

1.  A profiling subagent with a strict brief: read-only, never `tar_make()`, timings from `tar_meta()`, rewrites benchmarked on subsets loaded with `tar_read()`, scratch scripts outside the repo, findings returned with file:line, measured speedup and risk to output identity. The user picked what to implement.
2.  Beyond the slowest targets, it looked for **spread-out costs**: the same expensive function in several targets, and a big object reloaded by many targets (7 s × 9 loads).
3.  Ratios on subsets, then `identical(old, new)` on the full real data before adopting anything.
4.  Regression check: snapshot values and file hashes before, compare after (`tar_snapshot.R`). Tracing differences down to rows exposed a real data problem (ligature characters splitting words).

## What worked

| Change | Before → after | Exact? |
|----|----|----|
| Fixed-string prefilter before each dictionary regex (the literal must occur in any match) | 47.4 s → 7 s | yes, by construction |
| Regex only in a window around a rare anchor token | 55 s → 3.4 s, same 37,284 matches | argued from the pattern; **not exact in general** (see `vectorization.md`) |
| Compute once in a cache target for the union of IDs; consumers look up with `match()` and `stopifnot(!anyNA(i))` | 242k → 135k computations; consumers stopped loading the big table | yes |
| Lowercase once, then case-sensitive fixed search | 1.1 s per term → 0.5 s once + 0.14 s per term (about 100 s → 25 s) | ASCII only: a ligature changed a count from 14,541 to 14,576 in a naive version |
| Expensive function on distinct values: `f(u)[match(x, u)]` | 16.4 s → 7.2 s | yes (pure function) |
| `stri_replace_all_charclass()` instead of a regex character class | 2.6 s → 1.15 s per 60k texts | yes |
| Crew workers sized by an `NPROC` environment variable; worker deployment, transient memory | one slow plot stopped dominating wall time | yes |
| Shared memory (mori) for the big table across workers, with a custom format (`formats.R`) | fit in memory; no reload per worker | yes, after fixing two traps |
| Dynamic branching over 16 stored chunks for the big counting jobs | parallel counting | yes |
| Normalize text to ASCII once, early (fixed table, then transliterate only what remains) | full transliteration 117 s on 214k texts → 39 s for three columns | intended output change; also made the lowercase trick exact |

## What did not work

- Merging all patterns into one alternation regex: slower (13.6 s vs 4.1 s) and not identical (overlapping matches).
- A fixed prefilter before each synonym regex, where most texts contain the literal: slower (5.3 s vs 3.8 s). A case-insensitive fixed search costs more than it saves.
- Speeding up the slowest plot: impossible without changing the output.

## Traps hit

- Returning `mori::share(x)` from a target with an `rds` format and `cue = tar_cue("always")`: the stored value was only a region name, new on every run, so every downstream target rebuilt on every `tar_make()`. Fixed with a custom format that writes real data and re-shares on read (`sharing-mori.md`).
- `dplyr::mutate()` on a shared table keeps the untouched shared columns; saving the result with a plain writer stored only region names and failed in a later session. Fixed by making a copying format the default (`format_qs_unshared`).
- Transliteration side effects: `"µm"` became `"mm"` under a full Latin-ASCII transform; soft hyphens and zero-width spaces must become the empty string `""`, not a space `" "`.
- Mapping branches over a big shared table gives every branch a full copy unless it is shared; chunk it into separate stored targets instead (`branching.md`).

## Lessons that generalize

- Most of the gain came from **doing less work** (prefilters, unique values, computing once, smaller inputs), not from faster functions.
- The cheapest parallel win was making the slowest chain the only thing left on the critical path.
- Every non-trivial rewrite needed a full-data identity check; two "obviously exact" tricks were not.
- Guardrails held throughout: no `tar_make()` in a pipeline with deploy targets without approval, package installs only with approval, every change and its check recorded in the project's decisions log.

[^1]: Source: unpublished case notes from the pipeline author (session 1) (retrieved 2026-11-02; ~412k records (paraphrased)).
