---
paths:
  - "**/*.R"
  - "**/*.r"
  - "**/*.Rmd"
  - "**/*.qmd"
  - "**/DESCRIPTION"
  - "**/rproj.toml"
---

# R style

In a project with `_targets.R`, also follow `~/.config/agents/rules/targets.md`. Packages and environments: `~/.config/agents/rules/r-env.md`. Before running R code, check whether the `positron` MCP tools (`mcp__positron__*`) are available and `list_sessions` reports `positron_connected: true`. If so, read `~/.config/agents/context/r-positron.md` once and follow it; otherwise use `rig run`/`Rscript`.

## Skills
Load the general R skills by task:

| Task | Skill |
|---|---|
| Any tidyverse code | `tidyverse-patterns`, `r-style-guide` |
| Column-name arguments, tidy eval | `rlang-patterns` |
| Slow code, large data; parallel work | `r-performance`; `mirai` |
| Tests | `tdd-workflow`, `testing-r-packages` |
| Packages | `r-package-development`, `cli`, `lifecycle` |
| Quarto, figure alt text | `quarto-authoring`, `alt-text` |

## Idioms
- Modern tidyverse throughout. These rules are for new code: don't convert legacy code (`%>%`, old headers) in passing unless that is the task.
- Native `|>` only, never `%>%`. Use `\(x)` lambdas, `.by`, `join_by()`, `list_rbind()`, `case_when(.default = )`, `pick()`.
- No superseded/deprecated functions (e.g. `mutate(.keep = "none")` not `transmute()`, `.by` not `group_by()`/`ungroup()`, `recode_values()` not `case_match()`).
- Keep pipe chains short; break long ones into named intermediate objects.
- Functions: argument names match the objects/targets passed in; last line is the bare returned object, no `return()`. Early-return guard clauses, no `else` after `return`, `switch()` over if/else chains.
- One top-level function per file in `R/`, file named after the function; small helpers in `utils.R`.
- No OOP (S3/S4/S7/R6) without asking first.
- snake_case, 80-char lines. Format touched files with `air format`.
- Prefer existing package functions (tidyverse, readr, stringi, rlang, fs, sys) over custom helpers; httr2 over system `curl`. Favor packages already used in sibling repos.

## Namespacing
- Packages: no `library()` in package code, use `pkg::fn`, except for heavily used packages in `R/` (e.g. `dplyr`, `purrr`, `rlang`, `stringr`, `tibble`, `tidyr`) which can be loaded via NAMESPACE and @import. Use `@importFrom pkg fn` for a single function, `@import pkg` for many. Don't import entire packages unless they are used extensively in the package.
- Projects/pipelines: attach only heavily used packages in `packages.R` (or `tar_option_set(packages = )`) and call them unnamespaced. Don't namespace project functions.
- Less-used packages: namespace with `pkg::fn` in `R/` files. If one is used extensively in a single target, set it in that target's `packages` argument instead, and add a comment in the called function naming the package so it gets loaded when working outside the pipeline.

## Messages & errors
- Messages and errors via `cli` (`cli_abort()`, `cli_inform()`); conditions via `rlang`. Existing packages, scripts and pipelines: keep the package's or surrounding scripts'own style, even if it's base R.
- Fail loudly; never skip silently. Without tests, validate inline with `stopifnot()` or `rlang::check_*` on row counts, keys and totals.

## Standalone scripts
Analyses and one-off requests outside a pipeline.
- Run top to bottom from a clean session, from the project root (`Rscript <dir>/<script>.R`; in Positron, send the contents to a console, see `~/.config/agents/context/r-positron.md`), and write their own outputs next to the script.
- Header comment: how to run it, a numbered list of the questions it answers, the issue URL if any, and the vintage of every input (snapshot date, file date, or `tar_meta()` build time).
- `library()` calls at the top (or `source("packages.R")`), so the script runs alone. Load only the `R/` files it needs: `targets::tar_source(c("R/x.R", ...))`.
- Scripts outside a rig project declare dependencies in an inline header, run with `rig run script.R`. Create with `rig proj init --script script.R`, edit with `rig proj add --script script.R <pkg>` / `rig proj remove --script ...`, pin with `rig proj lock --script script.R` (commit `script.R.lock`). Same rules as `rproj.toml`: direct dependencies, `>=` minimums, `exclude-newer` pinned. The header goes above the descriptive header comment.
  ```r
  # /// script
  # [dependencies]
  # R = ">= 4.4"
  # dplyr = ">= 1.1"
  #
  # [tool.rig]
  # exclude-newer = "2026-06-01"
  # ///
  ```
- Parameters (`as_of`, `out_dir`, thresholds) as named variables near the top. `# Section ----` headers. Descriptive snake_case file names, no `01_` numbering.
- Freeze inputs that will change: cache the copy used, with its date in the file name (`x_2026-10-13.csv`), and stop if it's missing.

## Docs
- Functions in `R/` get terse roxygen blocks (title, non-trivial `@param`, `@returns`), even outside packages.
- Packages: never hand-edit `man/` or `NAMESPACE`; run `devtools::document()`.
- Packages whose `docs/` is pkgdown output: agent docs (`decisions.md`, `architecture.md`) go in `.agents/`, and `.Rbuildignore` lists `^AGENTS\.md$`, `^CLAUDE\.md$`, `^\.agents$`, `^\.claude$`.
- Private GitHub dependencies need `GITHUB_PAT`; record the install route in `AGENTS.md`.
- Comments: few, short, explain non-obvious why. Decisions, history, and architecture go in docs files.
- No hardcoded parameters or transcribed numbers in code. In `R/` functions, parameters are arguments; in scripts, named variables at the top. Transcribed values live in a CSV with a source.
