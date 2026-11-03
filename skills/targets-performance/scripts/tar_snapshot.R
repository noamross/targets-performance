#!/usr/bin/env Rscript
# Save target values and metadata, then compare a later store against them.
# Usage:
#   Rscript tar_snapshot.R save <dir> [store=_targets] [names...]
#   Rscript tar_snapshot.R compare <dir> [store=_targets]
#   The store may also be given by position (first argument after <dir>).
# Run from the project root (file-format targets are paths relative to it).
# save writes: <dir>/meta.rds, <dir>/files.rds (file targets: md5),
#   <dir>/<name>.qs2 (or .rds if qs2 is missing).
# compare exits 1 if any value differs or is missing. Data are compared exactly
#   (identical()). If values differ only in environment identity (formulas and
#   terms in lm/glm models, closures read back from disk) but the environments'
#   contents match, compare reports "EQUAL (environments differ)" and passes.
#   Formula/terms environments are ignored; other environments' contents count.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2 || !args[1] %in% c("save", "compare")) {
  stop("usage: tar_snapshot.R save|compare <dir> [store] [names...]")
}
cmd <- args[1]
dir <- args[2]
rest <- args[-(1:2)]
# Optional store: store=<path>, or the first remaining arg if it is a store directory.
store <- "_targets"
kv_store <- grep("^store=", rest, value = TRUE)
if (length(kv_store)) {
  store <- sub("^store=", "", kv_store[[1]]); rest <- rest[!grepl("^store=", rest)]
} else if (length(rest) && dir.exists(rest[1]) && file.exists(file.path(rest[1], "meta", "meta"))) {
  store <- rest[1]; rest <- rest[-1]
}
if (!dir.exists(store)) stop("store not found: ", store)
if (!requireNamespace("targets", quietly = TRUE)) stop("targets not installed")
has_qs2 <- requireNamespace("qs2", quietly = TRUE)

ext <- if (has_qs2) "qs2" else "rds"
write_val <- function(x, file) {
  if (has_qs2) qs2::qs_save(x, file) else saveRDS(x, file)
}
read_val <- function(file) {
  if (grepl("\\.qs2$", file)) qs2::qs_read(file) else readRDS(file)
}
file_hash <- function(paths) {
  ok <- file.exists(paths)
  h <- rep(NA_character_, length(paths))
  h[ok] <- unname(tools::md5sum(paths[ok]))
  data.frame(path = paths, md5 = h, stringsAsFactors = FALSE)
}

if (cmd == "save") {
  m <- as.data.frame(targets::tar_meta(store = store, fields = c("name", "type", "data", "format", "seconds", "bytes")))
  m <- m[m$type %in% c("stem", "pattern"), , drop = FALSE]
  names_to <- if (length(rest)) rest else m$name
  bad <- setdiff(names_to, m$name)
  if (length(bad)) stop("not in store: ", paste(bad, collapse = ", "))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  meta <- m[m$name %in% names_to, , drop = FALSE]
  saveRDS(meta, file.path(dir, "meta.rds"))
  files <- list()
  for (n in names_to) {
    fmt <- meta$format[meta$name == n]
    x <- targets::tar_read_raw(n, store = store)
    write_val(x, file.path(dir, paste0(n, ".", ext)))
    if (identical(fmt, "file")) files[[n]] <- file_hash(as.character(x))
  }
  saveRDS(files, file.path(dir, "files.rds"))
  cat("saved", length(names_to), "targets to", normalizePath(dir), "as", ext, "\n")
  quit(status = 0)
}

# compare
# Normalize environments so identical() compares data, not addresses.
# .Environment attributes of formulas and terms (lm/glm) become a placeholder.
# Global, package, namespace, base and empty environments become their name.
# Any other environment (closure from a function factory, R6 object, a value
# that is an environment) becomes a sorted list of its contents, so changed
# data inside it still DIFFERS; `seen` stops reference cycles.
env_label <- function(e) {
  if (identical(e, globalenv())) return("<globalenv>")
  if (identical(e, emptyenv())) return("<emptyenv>")
  if (identical(e, baseenv())) return("<baseenv>")
  if (isNamespace(e)) return(paste0("<namespace:", getNamespaceName(e), ">"))
  nm <- environmentName(e)
  if (nzchar(nm)) return(paste0("<env:", nm, ">"))
  NULL
}
strip_env <- function(x, seen = new.env()) {
  if (is.environment(x)) {
    lab <- env_label(x)
    if (!is.null(lab)) return(lab)
    id <- format(x)
    if (!is.null(seen[[id]])) return("<cycle>")
    seen[[id]] <- TRUE
    v <- as.list(x, all.names = TRUE, sorted = TRUE)
    return(list(env = lapply(v, strip_env, seen = seen), parent = strip_env(parent.env(x), seen)))
  }
  if (is.function(x) && !is.primitive(x)) {
    return(list(fun = {f <- x; environment(f) <- emptyenv(); f}, env = strip_env(environment(x), seen)))
  }
  a <- attributes(x)
  if (length(a)) {
    if (!is.null(a$.Environment)) a$.Environment <- "<environment>"
    nm <- setdiff(names(a), c(".Environment", "names", "dim", "dimnames", "row.names", "class", "levels"))
    for (k in nm) a[[k]] <- strip_env(a[[k]], seen)
    attributes(x) <- a
  }
  if (is.list(x) && !is.data.frame(x)) x[] <- lapply(x, strip_env, seen = seen)
  if (is.data.frame(x)) {
    is_rec <- vapply(x, \(col) is.list(col) || !is.null(attributes(col)), logical(1))
    if (any(is_rec)) x[is_rec] <- lapply(x[is_rec], strip_env, seen = seen)
  }
  x
}
why_differs <- function(old, new) {
  if (has_waldo) {
    d <- waldo::compare(old, new, max_diffs = 5, ignore_formula_env = TRUE, ignore_function_env = TRUE)
    if (length(d)) {
      out <- unlist(strsplit(utils::head(d, 3), "\n"))
      out <- out[nzchar(out)]
      if (length(out) > 15) out <- c(out[1:15], sprintf("... (%d waldo sections in all)", length(d)))
      return(out)
    }
  }
  ae <- all.equal(old, new)
  if (!isTRUE(ae)) return(utils::head(ae, 5))
  c(sprintf("types: %s vs %s; classes: %s vs %s", typeof(old), typeof(new),
    paste(class(old), collapse = "/"), paste(class(new), collapse = "/")),
    "no visible difference (likely attributes, external pointers or bit-level NaN/NA)")
}

saved <- readRDS(file.path(dir, "meta.rds"))
files <- readRDS(file.path(dir, "files.rds"))
cur <- as.data.frame(targets::tar_meta(store = store, fields = c("name", "data", "format")))
any_differs <- FALSE
has_waldo <- requireNamespace("waldo", quietly = TRUE)
for (i in seq_len(nrow(saved))) {
  n <- saved$name[i]
  f_old <- file.path(dir, paste0(n, ".", ext))
  alt <- file.path(dir, paste0(n, ".", if (ext == "qs2") "rds" else "qs2"))
  if (!file.exists(f_old) && file.exists(alt)) f_old <- alt
  if (!file.exists(f_old)) { cat(n, ": MISSING SNAPSHOT\n"); any_differs <- TRUE; next }
  old <- read_val(f_old)
  c_row <- cur[cur$name == n, , drop = FALSE]
  if (!nrow(c_row)) { cat(n, ": DIFFERS (missing in store)\n"); any_differs <- TRUE; next }
  new <- tryCatch(targets::tar_read_raw(n, store = store), error = function(e) e)
  if (inherits(new, "error")) { cat(n, ": DIFFERS (read error: ", conditionMessage(new), ")\n", sep = ""); any_differs <- TRUE; next }
  hash_note <- if (identical(saved$data[i], c_row$data[1])) "" else " [data hash changed]"
  if (identical(old, new)) {
    cat(n, ": IDENTICAL", hash_note, "\n", sep = "")
  } else if (identical(strip_env(old), strip_env(new))) {
    cat(n, ": EQUAL (environments differ)", hash_note, "\n", sep = "")
  } else {
    any_differs <- TRUE
    cat(n, ": DIFFERS", hash_note, "\n", sep = "")
    cat(paste0("  ", why_differs(old, new)), sep = "\n")
  }
  if (!is.null(files[[n]])) {
    now <- file_hash(files[[n]]$path)
    changed <- files[[n]]$path[is.na(now$md5) | now$md5 != files[[n]]$md5]
    if (length(changed)) {
      any_differs <- TRUE
      cat("  changed files:\n"); cat(paste0("    ", changed), sep = "\n")
    }
  }
}
quit(status = if (any_differs) 1L else 0L)
