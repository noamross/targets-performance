ducklake_env <- local({
  state <- new.env(parent = emptyenv())
  function() state
})

#' Default public base URL for the USAspending DuckLake archive
#'
#' Resolved from `getOption("duckspending.base_url")`, then the
#' `DUCKSPENDING_BASE_URL` environment variable, then the default
#' production URL. Override via `option(duckspending.base_url = ...)`
#' or `DUCKSPENDING_BASE_URL=...` for testing.
#'
#' @returns A character scalar, no trailing slash.
#' @keywords internal
default_base_url <- function() {
  opt <- getOption("duckspending.base_url", "")
  env <- Sys.getenv("DUCKSPENDING_BASE_URL", unset = "")
  url <- if (nzchar(opt)) {
    opt
  } else if (nzchar(env)) {
    env
  } else {
    "https://usaspending.grant-witness.us"
  }
  sub("/+$", "", url)
}

#' Hidden ATTACH alias used internally for a snapshot's underlying catalog
#'
#' The schema-views layer in the memory database is what users see; this
#' alias is the actual database the views read from.
#'
#' @param date YYYYMMDD character scalar.
#' @keywords internal
.dl_alias <- function(date) paste0("_dl_", date)

#' Normalise a snapshot identifier to a YYYYMMDD character scalar.
#'
#' Accepts character (`"20260206"` or `"2026-02-06"`), `Date`, or numeric
#' (e.g. `20260206`). Rejects malformed inputs early.
#'
#' @param x Input value.
#' @returns YYYYMMDD character scalar.
#' @keywords internal
.normalise_date <- function(x) {
  if (inherits(x, "Date")) {
    return(format(x, "%Y%m%d"))
  }
  if (is.numeric(x)) {
    x <- formatC(x, format = "d", flag = "0", width = 8L)
  }
  if (!is.character(x) || length(x) != 1L) {
    cli::cli_abort(
      "Snapshot date must be a single character/Date/numeric value."
    )
  }
  x <- gsub("[^0-9]", "", x)
  if (!grepl("^[0-9]{8}$", x)) {
    cli::cli_abort("Snapshot {.val {x}} is not a valid YYYYMMDD string.")
  }
  x
}

#' Snapshot catalog URL for a given date.
#' @param date YYYYMMDD character scalar.
#' @param base_url Base URL (no trailing slash).
#' @keywords internal
.snapshot_url <- function(date, base_url = default_base_url()) {
  paste0(base_url, "/snapshots/", date, "/usaspending.ducklake")
}

#' Local cache path for a snapshot's catalog file.
#'
#' One catalog per date is small (~20–700 MB) and immutable (each
#' YYYYMMDD prefix is written once), so the cache never invalidates.
#' We do not check ETags for snapshot catalogs.
#'
#' @keywords internal
.snapshot_cache_path <- function(date, catalog_dir) {
  file.path(catalog_dir, "snapshots", date, "usaspending.ducklake")
}

#' Download a snapshot catalog locally if not already cached.
#'
#' @returns Character path on disk.
#' @keywords internal
.cache_snapshot <- function(date, base_url, catalog_dir) {
  dest <- .snapshot_cache_path(date, catalog_dir)
  if (file.exists(dest) && file.size(dest) > 0L) {
    return(dest)
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  url <- .snapshot_url(date, base_url)
  utils::download.file(url, dest, mode = "wb", quiet = TRUE)
  dest
}

#' Attach a snapshot's catalog under its hidden alias.
#'
#' When the catalog is loaded from a local cache (the default), DuckLake
#' would resolve its stored relative `data/` path against the local
#' file's directory — but only the catalog is cached locally, not the
#' parquet files. Any query that actually scans data then errors with
#' `Cannot open file "data/main/<table>/<file>.parquet"`. To make
#' cached-catalog reads work seamlessly, we override `DATA_PATH` on the
#' ATTACH to point at the remote bucket's `snapshots/<date>/data/`
#' prefix; httpfs serves the parquets directly from there.
#'
#' When `download_catalog = FALSE` we attach the catalog over HTTP
#' directly, so the catalog's relative `data/` resolves correctly
#' against its own remote location and no override is needed.
#'
#' @keywords internal
.attach_snapshot <- function(
  con,
  date,
  base_url,
  catalog_dir,
  download_catalog = TRUE
) {
  alias <- .dl_alias(date)
  if (isTRUE(download_catalog)) {
    source <- .cache_snapshot(date, base_url, catalog_dir)
    # If the cached catalog stored a relative `data/` path but the
    # data files aren't sitting next to it locally, rewrite the
    # catalog's `ducklake_metadata.data_path` to the absolute remote
    # URL so DuckLake resolves parquet reads against R2. The rewrite
    # is idempotent (only happens when the stored value is relative
    # AND no local data dir exists), so re-using the cache is cheap.
    local_data <- file.path(dirname(source), "data")
    if (!.dir_has_content(local_data)) {
      .ensure_remote_data_path(source, .snapshot_data_url(date, base_url))
    }
  } else {
    source <- .snapshot_url(date, base_url)
  }

  safe_source <- gsub("'", "''", source)
  # NB: DuckLake's `ducklake:` URI prefix and the `TYPE ducklake` option
  # are mutually exclusive — passing both errors with "does not exist".
  # We use the URI prefix; READ_ONLY is OK without TYPE.
  DBI::dbExecute(
    con,
    sprintf(
      "ATTACH 'ducklake:%s' AS %s (READ_ONLY)",
      safe_source,
      DBI::dbQuoteIdentifier(con, alias)
    )
  )
  invisible(alias)
}

#' Rewrite a cached catalog's stored data_path to an absolute URL.
#'
#' DuckLake refuses an ATTACH-time `DATA_PATH` override that differs
#' from the value baked into the catalog, so we mutate the catalog
#' itself. Idempotent: a catalog already pointing at an absolute URL is
#' left alone, and the rewrite only runs when the stored value is
#' relative (i.e. doesn't start with `/`, `s3://`, `gs://`, or `http`).
#'
#' Probes the catalog file read-only first so concurrent R sessions
#' that already attached the cached catalog don't fight over a writer
#' lock on the underlying DuckDB file. Only re-opens read-write if a
#' rewrite is actually needed (cold-cache, first-ever attach). Each
#' probe connection is fully disconnected with `shutdown = TRUE` before
#' the next one is opened, because the duckdb R driver caches open
#' databases by path and reusing one with a different `read_only` flag
#' fails with "attached in read-only mode".
#'
#' @keywords internal
.ensure_remote_data_path <- function(catalog_path, remote_data_url) {
  current <- .probe_data_path(catalog_path)
  if (is.null(current) || length(current) == 0L) {
    return(invisible(FALSE))
  }
  if (grepl("^([a-z]+://|/)", current, perl = TRUE)) {
    # Already absolute — no rewrite needed; the read-only probe was
    # enough and we never need a writer lock.
    return(invisible(FALSE))
  }

  rw_con <- DBI::dbConnect(
    duckdb::duckdb(),
    dbdir = catalog_path,
    read_only = FALSE
  )
  on.exit(
    try(DBI::dbDisconnect(rw_con, shutdown = TRUE), silent = TRUE),
    add = TRUE
  )
  target <- paste0(sub("/+$", "", remote_data_url), "/")
  DBI::dbExecute(
    rw_con,
    sprintf(
      "UPDATE ducklake_metadata SET value = '%s' WHERE key = 'data_path'",
      gsub("'", "''", target)
    )
  )
  invisible(TRUE)
}

#' Read-only probe of a cached catalog's data_path.
#'
#' Kept as a small helper so the read-only DBI handle is opened and
#' fully shut down inside a single function scope, releasing the
#' driver's cached database entry before `.ensure_remote_data_path`'s
#' caller may need a writable handle on the same file.
#'
#' @returns Character scalar or NULL.
#' @keywords internal
.probe_data_path <- function(catalog_path) {
  ro_con <- tryCatch(
    DBI::dbConnect(duckdb::duckdb(), dbdir = catalog_path, read_only = TRUE),
    error = function(e) NULL
  )
  if (is.null(ro_con)) {
    return(NULL)
  }
  on.exit(
    try(DBI::dbDisconnect(ro_con, shutdown = TRUE), silent = TRUE),
    add = TRUE
  )
  tryCatch(
    DBI::dbGetQuery(
      ro_con,
      "SELECT value FROM ducklake_metadata WHERE key = 'data_path'"
    )$value,
    error = function(e) NULL
  )
}

#' Remote URL of a snapshot's parquet data directory.
#'
#' Matches the layout written by the migration pipeline:
#' `<base>/snapshots/<date>/data/`.
#' @keywords internal
.snapshot_data_url <- function(date, base_url = default_base_url()) {
  paste0(base_url, "/snapshots/", date, "/data")
}

#' Is `path` a directory that contains at least one entry?
#' @keywords internal
.dir_has_content <- function(path) {
  if (!dir.exists(path)) {
    return(FALSE)
  }
  length(list.files(path, all.files = FALSE, recursive = FALSE, no.. = TRUE)) >
    0L
}

#' Project an attached snapshot as a top-level schema in the memory DB.
#'
#' Creates schema `"YYYYMMDD"` (or `"latest"`) and a per-user-table view
#' inside it that selects from the snapshot's `<hidden>.main.<table>`.
#'
#' All DDL is qualified with `memory.` so projection always lands in the
#' user-facing in-memory catalog. Without that qualification, DuckDB
#' creates the schema in whatever the current catalog happens to be —
#' which after an `ATTACH ... READ_ONLY` can silently be the attached
#' catalog, and read-only attached catalogs swallow the CREATE without
#' an error, so the schema effectively disappears from the pane.
#'
#' @param replace_existing If TRUE, drops the schema first.
#' @keywords internal
.project_schema <- function(
  con,
  schema_name,
  source_alias,
  replace_existing = FALSE
) {
  schema_ident <- DBI::dbQuoteIdentifier(con, schema_name)
  alias_ident <- DBI::dbQuoteIdentifier(con, source_alias)
  qualified_schema <- sprintf("memory.%s", schema_ident)

  if (isTRUE(replace_existing)) {
    DBI::dbExecute(
      con,
      sprintf("DROP SCHEMA IF EXISTS %s CASCADE", qualified_schema)
    )
  }
  DBI::dbExecute(
    con,
    sprintf("CREATE SCHEMA IF NOT EXISTS %s", qualified_schema)
  )

  # User tables only — skip the _snapshots marker and anything DuckLake-internal.
  tables <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT table_name
       FROM duckdb_tables()
       WHERE database_name = ? AND schema_name = 'main'
         AND NOT starts_with(table_name, '_')
         AND NOT starts_with(table_name, 'ducklake_')
       ORDER BY table_name"
    ),
    params = list(source_alias)
  )
  for (tbl in tables$table_name) {
    DBI::dbExecute(
      con,
      sprintf(
        "CREATE OR REPLACE VIEW %s.%s AS SELECT * FROM %s.main.%s",
        qualified_schema,
        DBI::dbQuoteIdentifier(con, tbl),
        alias_ident,
        DBI::dbQuoteIdentifier(con, tbl)
      )
    )
  }
  invisible(tables$table_name)
}

#' Build a multi-catalog DuckLake connection.
#'
#' Internal worker behind [duckspending_connection()].
#'
#' @param snapshots Character vector of YYYYMMDD dates to attach,
#'   already validated and normalised.
#' @param latest The date that the `latest` schema should mirror.
#' @param cache Logical; when `TRUE` (default) install and load the
#'   `cache_httpfs` community extension to persist fetched parquet
#'   blocks on disk.  Set to `FALSE` to skip caching.
#' @returns A `duckspending_connection`.
#' @keywords internal
ducklake_connection <- function(
  snapshots,
  latest,
  base_url = default_base_url(),
  catalog_dir = tools::R_user_dir("duckspending", which = "cache"),
  download_catalog = TRUE,
  open_pane = TRUE,
  cache = TRUE
) {
  dir.create(catalog_dir, recursive = TRUE, showWarnings = FALSE)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(
    if (!is.null(con) && DBI::dbIsValid(con)) {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    },
    add = TRUE
  )

  DBI::dbExecute(
    con,
    "INSTALL httpfs;  INSTALL ducklake; LOAD httpfs; LOAD ducklake;"
  )

  cache_loaded <- FALSE
  if (isTRUE(cache)) {
    cache_dir <- file.path(catalog_dir, "httpfs_cache")
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_loaded <- tryCatch(
      {
        DBI::dbExecute(
          con,
          "INSTALL cache_httpfs FROM community; LOAD cache_httpfs;"
        )
        safe_cache_dir <- gsub("'", "''", cache_dir)
        DBI::dbExecute(
          con,
          sprintf("SET cache_httpfs_cache_directory = '%s'", safe_cache_dir)
        )
        TRUE
      },
      error = function(e) {
        cli::cli_warn(
          c(
            "Could not enable on-disk HTTP cache ({.pkg cache_httpfs}).",
            i = "Proceeding without disk cache.",
            x = conditionMessage(e)
          )
        )
        FALSE
      }
    )
  }

  for (d in snapshots) {
    .attach_snapshot(con, d, base_url, catalog_dir, download_catalog)
    .project_schema(con, d, .dl_alias(d))
  }
  if (!is.null(latest) && latest %in% snapshots) {
    .project_schema(con, "latest", .dl_alias(latest), replace_existing = TRUE)
  }

  con <- upgrade_connection(
    con,
    list(
      base_url = base_url,
      catalog_dir = catalog_dir,
      snapshots = snapshots,
      latest = latest,
      cache = cache_loaded,
      cache_dir = if (cache_loaded) cache_dir else NULL
    )
  )

  if (isTRUE(open_pane) && requireNamespace("connections", quietly = TRUE)) {
    try(connections::connection_view(con), silent = TRUE)
  }
  on.exit() # cancel disconnect; ownership transfers to caller
  con
}
