---
paths:
  - "**/rproj.toml"
  - "**/rproj.lock"
  - "**/DESCRIPTION"
  - "**/.Rprofile"
  - "**/renv.lock"
  - "**/.renvignore"
---

# R environments

## rig projects (new projects)
- Manage packages with rig projects (`rproj.toml` manifest, `rproj.lock`, library in `.rvenv/lib`), not renv or pak. Add packages with `rig proj add <pkg>`, never `install.packages()` into the project. Run entry points via `rig run` (`rig run make`, `rig run test`). Existing projects keep their current tool.
- `rproj.toml` lists direct dependencies only, with `>=` minimums, and pins `exclude-newer` in `[tool.rig]`. Upgrade deliberately: bump `exclude-newer`, run `rig proj lock --upgrade` (or `-P pkg` for a single package), run the tests, and commit `rproj.toml` and `rproj.lock` together.
- Dev tools live in rig's shared `tools` library (per R version, on every project's library path), never in `rproj.toml`: devtools, usethis, renv (for dependency scanning), datapasta, milesmcbain/tflow, milesmcbain/fnmate. Set up with `rig library add tools`, then `rig pkg install -l tools <pkgs>`.
- Commit `.rvenvlib/` (keep `!.rvenvlib/**` in `.gitignore`); never commit or copy `.rvenv/`.
- `check_deps()`: add it to new rig projects' `.Rprofile` by copying `~/.config/agents/templates/check_deps.R`. Define it unguarded (a function definition is cheap, and `rig run --rscript -e 'check_deps()'` needs it in non-interactive sessions). Never call it at startup unless wrapped in `if (interactive() && !nzchar(Sys.getenv("TAR_ACTIVE")))`. Run it after adding or removing `library()` / `pkg::` calls and before commits. Fix **missing** with `rig proj add`. Review **unused** with the user before `rig proj remove`: a package may be needed only indirectly, in which case add it to `ignore`.

## renv projects (existing)
- After dependency changes and before commits, run `renv::status()`, then `renv::clean()`. It removes stale `00LOCK` dirs and temp dirs, and unused packages from the project library; confirm removals with the user. Use `renv::purge(pkg, version = )` only for corrupted or obsolete cache entries, and ask first: it deletes from the shared cache and breaks other projects that link to that package.
- `.renvignore` can hide packages used only in `scripts/`, `notes/` or analysis folders. List those in the folder's `AGENTS.md` and ask before adding them to the lock.

## Both
- Ask before installing or upgrading packages. Don't upgrade in passing. Don't run `renv::restore()`/`snapshot()` or `rig proj lock --upgrade` unasked.
