#' Connect to the USAspending DuckLake archive
#'
#' Opens a DuckDB connection with one or more monthly DuckLake snapshots
#' attached. Each attached snapshot is exposed as a top-level schema named
#' after its date (`"20260206"`, `"20260306"`, ...). A `latest` schema
#' mirrors the newest attached snapshot for convenience.
#'
#' By default a single snapshot — the newest one announced by the public
#' manifest — is attached. To attach a specific set, pass `snapshots = ...`.
#'
#' The first call with default arguments caches its connection in a
#' package-level environment; subsequent default calls reuse it, so all
#' the other `duckspending_*` helpers that default `conn = duckspending_connection()`
#' share a single underlying DuckDB session. Calls with non-default
#' arguments are not cached.
#'
#' @param snapshots Snapshot selector. One of:
#'   - `"latest"` (default): attach only the newest snapshot per
#'     [`duckspending_snapshots()`].
#'   - `"all"`: attach every snapshot in the manifest.
#'   - A character vector of YYYYMMDD strings, or coercible
#'     (`Date` or numeric), naming the snapshots to attach.
#' @param base_url Base URL of the public archive. Override for testing
#'   via `options(duckspending.base_url=)` or the `DUCKSPENDING_BASE_URL`
#'   env var; defaults to <https://usaspending.grant-witness.us>.
#' @param catalog_dir Local cache directory for snapshot catalog files.
#' @param download_catalog Logical; when `TRUE` (default) catalog files
#'   are cached locally before attaching, when `FALSE` the catalog is
#'   attached directly over HTTP.
#' @param open_pane Logical; when `TRUE` (default) and the
#'   \pkg{connections} package is available, register the connection
#'   with the IDE Connections pane.
#' @param cache Logical; when `TRUE` (default) the `cache_httpfs`
#'   community extension is loaded to persist fetched parquet blocks on
#'   disk, speeding up repeated and parallel queries.  Override via
#'   `options(duckspending.cache = FALSE)` or
#'   `DUCKSPENDING_CACHE=false`.  Set to `FALSE` to skip caching.
#' @param new_conn Logical; when `TRUE` force a new connection even if a
#'   cached default exists.
#' @returns A `duckspending_connection` (`duckdb_connection` subclass).
#' @export
#' @examples
#' \dontrun{
#' con <- duckspending_connection()
#' duckspending_tbl("subaward_search")  # uses the cached default
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
duckspending_connection <- function(
  snapshots = "latest",
  base_url = default_base_url(),
  catalog_dir = tools::R_user_dir("duckspending", which = "cache"),
  download_catalog = TRUE,
  open_pane = TRUE,
  cache = .duckspending_cache_default(),
  new_conn = FALSE
) {
  available <- tryCatch(
    duckspending_snapshots(base_url = base_url, cache_dir = catalog_dir),
    error = function(e) character(0)
  )

  resolved <- .resolve_snapshots(snapshots, available)
  if (length(resolved) == 0L) {
    cli::cli_abort(c(
      "No snapshots to attach.",
      i = "Pass {.code snapshots = c(\"YYYYMMDD\", ...)} explicitly, or ensure {.url {paste0(base_url, '/snapshots.txt')}} is reachable."
    ))
  }

  latest <- if (length(available) > 0L) available[[1]] else resolved[[1]]
  if (!latest %in% resolved) {
    latest <- resolved[[1]]
  }

  cache_key <- paste(
    paste(resolved, collapse = ","),
    base_url,
    catalog_dir,
    as.integer(download_catalog),
    as.integer(isTRUE(cache)),
    sep = "::"
  )
  state <- ducklake_env()
  if (!isTRUE(new_conn)) {
    cached <- state$connections[[cache_key]]
    if (!is.null(cached) && DBI::dbIsValid(cached)) {
      return(cached)
    }
  }

  con <- ducklake_connection(
    snapshots = resolved,
    latest = latest,
    base_url = base_url,
    catalog_dir = catalog_dir,
    download_catalog = download_catalog,
    open_pane = open_pane,
    cache = cache
  )

  if (is.null(state$connections)) {
    state$connections <- list()
  }
  state$connections[[cache_key]] <- con
  state$cache_keys[[format(con@conn_ref)]] <- cache_key
  con
}

#' Replace a cached connection in-place after a mutating helper updates
#' its metadata. No-op for non-cached connections.
#' @keywords internal
.refresh_cached_connection <- function(con) {
  state <- ducklake_env()
  key <- state$cache_keys[[format(con@conn_ref)]]
  if (!is.null(key)) {
    state$connections[[key]] <- con
  }
  invisible(con)
}

#' Default value for the `cache` argument of [duckspending_connection()].
#'
#' Checks `getOption("duckspending.cache")` then the
#' `DUCKSPENDING_CACHE` env var, falling back to `TRUE`.
#' @keywords internal
.duckspending_cache_default <- function() {
  opt <- getOption("duckspending.cache", NULL)
  if (!is.null(opt)) {
    return(isTRUE(opt))
  }
  env <- Sys.getenv("DUCKSPENDING_CACHE", unset = "")
  if (nzchar(env)) {
    return(!tolower(env) %in% c("false", "0", "no"))
  }
  TRUE
}

#' Clear the on-disk HTTP cache for a duckspending connection
#'
#' Calls `cache_httpfs_clear_cache()` on the underlying DuckDB session to
#' delete all cached parquet blocks from disk. Useful when you want to force
#' fresh fetches or reclaim disk space.
#'
#' Has no effect (with a message) if the connection was opened with
#' `cache = FALSE` or if the `cache_httpfs` extension failed to load.
#'
#' @param conn A `duckspending_connection`. Defaults to the cached default
#'   [duckspending_connection()].
#' @returns `conn`, invisibly.
#' @export
duckspending_clear_cache <- function(conn = duckspending_connection()) {
  meta <- methods::slot(conn, "meta")
  if (!isTRUE(meta$cache)) {
    cli::cli_inform(
      "No active on-disk cache for this connection (opened with {.code cache = FALSE})."
    )
    return(invisible(conn))
  }
  DBI::dbExecute(conn, "SELECT cache_httpfs_clear_cache()")
  cli::cli_inform("On-disk HTTP cache cleared.")
  invisible(conn)
}

#' Resolve the user's snapshot selector to a concrete date vector.
#'
#' @param snapshots Input selector (see [duckspending_connection()]).
#' @param available Output of [duckspending_snapshots()], newest first.
#' @returns Character vector of YYYYMMDD dates, newest first.
#' @keywords internal
.resolve_snapshots <- function(snapshots, available) {
  if (is.character(snapshots) && length(snapshots) == 1L) {
    if (identical(snapshots, "latest")) {
      if (length(available) == 0L) {
        cli::cli_abort(c(
          "Cannot resolve {.val latest}: snapshot manifest unreachable.",
          i = "Pass {.code snapshots = \"YYYYMMDD\"} explicitly."
        ))
      }
      return(available[1])
    }
    if (identical(snapshots, "all")) {
      if (length(available) == 0L) {
        cli::cli_abort(
          "Cannot resolve {.val all}: snapshot manifest unreachable."
        )
      }
      return(available)
    }
  }
  dates <- vapply(snapshots, .normalise_date, character(1))
  sort(unique(unname(dates)), decreasing = TRUE)
}
