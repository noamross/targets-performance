# Custom {targets} formats for qs2 / parquet targets, with and without {mori} shared memory.
# Use: source("formats.R") (or paste into _targets.R), then tar_target(x, f(), format = format_qs_shared).
# Each object is self-contained: tar_format() ships read/write to workers, so helpers live inside the functions.
#
# format_qs_shared    big target built in the main process (deployment = "main", memory = "persistent");
#                     write stores real data (rlang::duplicate), read re-shares with mori::share().
#                     Consumers: retrieval = "main" so workers receive only the region name.
# format_qs_unshared  default format for every other target: copies mori-shared objects (anywhere in a
#                     recursive list) before qs2::qs_save(), because saving a shared vector writes only
#                     the region name and a later read fails with "shared memory region not found".
# format_parquet_shared    nanoparquet data frames; parquet writes values, so no copy is needed on write.
# format_parquet_unshared  plain nanoparquet (same as tarchetypes::tar_format_nanoparquet() defaults).

format_qs_shared <- targets::tar_format(
  read = function(path) mori::share(qs2::qs_read(path)),
  write = function(object, path) qs2::qs_save(rlang::duplicate(object), path)
)

format_qs_unshared <- targets::tar_format(
  read = function(path) qs2::qs_read(path),
  write = function(object, path) {
    has_shared <- function(x) {
      if (mori::is_shared(x)) return(TRUE)
      is.list(x) && any(vapply(unclass(x), has_shared, logical(1)))
    }
    if (has_shared(object)) object <- rlang::duplicate(object)
    qs2::qs_save(object, path)
  }
)

format_parquet_shared <- targets::tar_format(
  read = function(path) mori::share(nanoparquet::read_parquet(path)),
  write = function(object, path) nanoparquet::write_parquet(object, path)
)

format_parquet_unshared <- targets::tar_format(
  read = function(path) nanoparquet::read_parquet(path),
  write = function(object, path) nanoparquet::write_parquet(object, path)
)
