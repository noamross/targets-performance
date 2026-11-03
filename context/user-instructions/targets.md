---
paths:
  - "**/_targets*.R"
  - "**/_targets.yaml"
  - "**/packages.R"
  - "**/.Rprofile"
---

# targets pipelines

Also follow `~/.config/agents/rules/r.md`.

## Structure
- The targets pipeline is the organizing spine. Use `tarchetypes::tar_assign()` syntax (`name <- f(x) |> tar_target()`).
- Short targets (a couple of lines) inline in `_targets.R`; longer logic as functions in `R/`. Reuse intermediate targets; DRY.
- Large pipelines: split into `_targets_<group>.R` files, each defining `<group>_targets`. Options, controllers, and fixed parameters go in `_targets_settings.R`. `_targets.R` sources them all and collects them with `mget(ls(pattern = "_targets$"))`. Load functions with `tar_source()`.
- Name functions as verbs and targets as nouns; never give a function the same name as a target.

## Project `.Rprofile`
- Keep it minimal: every target's worker R session (callr, crew) runs it. No `library()` of dev packages (devtools, usethis, tflow), no diagnostics (`check_deps()`, status checks), no messages or network calls.
- Put anything interactive-only behind `if (interactive() && !nzchar(Sys.getenv("TAR_ACTIVE")))`. Definitions (e.g. `check_deps <- function()`) can stay outside the guard; calls and attaches go inside.

## Inputs & parameters
- Parameters set in `_targets.R`, not hardcoded. No `Sys.Date()` in pipeline logic: pin as-of dates and snapshot IDs as targets (`as_of <- as.Date("2026-09-30") |> tar_target()`).
- Track every input file or directory with `tar_file()` / `tar_url()` so edits propagate.
- Rules, recodes, and scenario grids are tribble targets applied with joins or `tar_map(values =)`, not `case_when()` buried in `R/`.
- Branching: static `tar_map()` for small named sets (agencies, countries); dynamic `pattern = map()` for data-driven sets (files, keys).
- Network fetches are explicit pull targets with a deliberate refresh policy: `tar_age()` or an env-flag force cue (`tar_cue_force(Sys.getenv("UPDATE") == "1", command = FALSE, depend = FALSE)`), so code edits don't re-fetch. Rate-limited hosts get their own one-worker crew controller.
- Cues by kind: `tar_age()` for periodic pulls; `tar_cue("always")` for deploy and "last updated" targets; `tar_cue("never")` for expensive fits run by hand.
- If the refresh flag works through an invalidation list instead of a force cue, fail on names that don't match a target (no `purrr::safely()`); stale names otherwise stop refreshing without anyone noticing.
- Write new targets with `tar_assign()`; `tar_plan()` blocks are legacy.

## Store & performance
- Never delete `_targets/` or run `tar_destroy()` without asking; stores can hold snapshots that can't be recreated. Check `tar_outdated()` before `tar_make()` after editing shared fetch helpers.
- Formats: `qs`/`qs2` by default; parquet for large tables. Big data: `memory = "transient"` (the default `"auto"`, since targets 1.11, is transient except for non-dynamic targets that other targets dynamically branch over; the default `retrieval = "auto"` acts like `"worker"` except for dynamic branches over non-dynamic targets, where it acts like `"main"`; with worker retrieval, memory settings barely matter). `garbage_collection` is an integer (targets >= 1.9; default 0 since 1.11): `gc()` runs every N targets on each worker, and `TRUE` means 1. Set 1 only when memory is tight, since each `gc()` costs time; otherwise use a larger N or leave it at 0. Target-level `garbage_collection = TRUE` on the few big targets is often enough.
- Parallelism: crew controller sized by `NPROC` env var, default serial. `error = Sys.getenv("TARGETS_ERROR", "stop")` with `workspace_on_error = TRUE`.
- Crew: off when `NPROC` ≤ 1. Otherwise a controller group: `primary` plus a one-worker controller per rate-limited host, with logs per controller. Pin fetch targets to their host with `resources = tar_resources(crew = tar_resources_crew(controller = "<host>"))`.

## Validation, outputs & deploys
- Validation lives in the DAG: check targets feed one assert target that errors, so `tar_make()` fails. Put `stopifnot()` sanity checks inside fetch and parse functions.
- Side-effecting targets (deploys, uploads, pushes) are isolated, named `*_deployed`, gated by a `DEPLOY` env var, and never run without approval.
- Never run a bare `tar_make()` in a pipeline that has deploy targets. Build named targets, after checking what is upstream with `tar_outdated(names = x)` or `tar_visnetwork(names = x, targets_only = TRUE)`.
- Keep deploy targets out of the group lists people build as a unit. `<group>_targets` must not contain the deployer; put deployers in a separate `<group>_deployed` list, so `tar_make(<group>_targets)` is always safe.
- Keep the `*_deployed` naming strict, so `tar_manifest(names = ends_with("_deployed"))` lists every external write. If the naming has drifted, keep a script that lists the writer targets.
- Before `tar_read()`, check `tar_meta(names = x, fields = time)` (the store may be stale or missing) and report that build time as the data vintage.
- Don't serialize ggplot objects; call plot functions from the qmd. Every chart gets a CSV of its data.
- Reports via `tar_quarto()`. Qmds stay thin (`tar_read()`/`tar_load()` only), render standalone, and take inline numbers from a values target, never typed in.
- CI (GitHub Actions): set up the R environment, restore and save `_targets/` with `actions/cache`, and run `tar_make()`; `UPDATE`/`NPROC`/`DEPLOY` are inputs.
