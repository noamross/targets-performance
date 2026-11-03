# targets-performance

An agent skill for diagnosing and speeding up R [{targets}](https://docs.ropensci.org/targets/) pipelines, built from web research and local benchmarks.

It profiles a pipeline's store, build graph and machine with shipped read-only scripts, predicts what each change will buy, and proposes strategies ranked by gain, exactness and risk: fast replacement functions, vectorization and string tricks, operation order, storage formats and partial reads, memory settings, branching and batching, crew parallelism without thread oversubscription, shared memory with mori, remote parquet with duckdb, downloads, BLAS and worker start-up. Every recommendation carries a measured speedup and its output-identity risk, and the user picks what to implement.

- `skills/targets-performance/SKILL.md`: the method, guardrails, and a symptom → strategy → reference table.
- `skills/targets-performance/references/`: one topic per page, loaded on demand. Numbers are generated from the benchmark results.
- `skills/targets-performance/scripts/`: `check_versions.R`, `machine_profile.R`, `tar_profile.R`, `tar_dag.R`, `startup_cost.R`, `profile_pipeline.R` + `profile_summary.R`, `tar_snapshot.R`, `formats.R`.
- `skills/targets-performance-update/`: a sub-skill that reruns the benchmarks and regenerates the references.

## Install

As a Claude Code plugin from a clone of this repository:

```sh
claude plugin marketplace add <path or git URL of this repository>
claude plugin install targets-performance@targets-performance
# other agents: copy or symlink skills/targets-performance into the agent's skills directory
```

## Use

In a {targets} project, ask the agent to speed up the pipeline (or invoke the `targets-performance` skill). The scripts can also run by hand from the project root:

```sh
Rscript path/to/skills/targets-performance/scripts/tar_profile.R _targets 20 script=_targets.R
```

## Repository layout

| Path | What |
|---|---|
| `skills/` | the two skills (what users install) |
| `bench/` | benchmark scripts per topic (packages in `rproj.toml`); results in `bench/<topic>/results/*.csv` |
| `bench/suite.csv`, `bench/run_suite.R` | which scripts run where (CI flag, needs, minimum cores and RAM) and the capped cross-platform runner |
| `.github/workflows/benchmarks.yml` | reruns the suite on Linux, macOS and Windows runners (x64/arm64, several BLAS libraries, R release and devel) when versions change; results on the `bench-results` branch |
| `bench/report/` | Quarto sources of the references (`*.qmd`, `_helpers.R`) |
| `bench/docker/` | optional Linux container runs with CPU/memory limits |
| `data/sources/` | sourced facts and published values (URL, date, quote) |
| `context/` | snapshots of the instructions, skills and example code that shaped the skill |
| `docs/` | decisions and architecture |

## Rerun benchmarks and regenerate

```sh
cd bench && Rscript run_suite.R topics=storage   # one script at a time, each under a memory cap
Rscript bench/refresh_outputs.R                  # from the repo root: versions, throughput, references, checks
```

The `targets-performance-update` skill describes the full procedure, including CI results, NEWS checks and source re-verification.

## License

MIT.
