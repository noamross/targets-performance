source("storage/_storage.R")
which <- commandArgs(TRUE)
fmt_n <- function(n) sub("e\\+0?", "e", sprintf("%g", n))
if (!length(which) || "a" %in% which) {
  na <- max_fit_n(c(1e6, 2.5e6, 1e7), 80, 14) # measured: ~14x the object while arrow/duckdb writes run
  if (is.na(na)) message("skipping a_numdf: memory budget too small") else {
    a <- make_a(na); message("a: ", format(object.size(a), units = "MB"))
    bench_object(a, "a_numdf", names(M_ALL)[!names(M_ALL) %in% c("qd_t1_noalt")], na, notes = sprintf("%s x 10 dbl/int data.frame", fmt_n(na)))
    rm(a); gc()
  }
}
if (!length(which) || "b" %in% which) {
  nb <- max_fit_n(c(1e5, 3e5, 1e6), 900, 20) # measured peak ~21x serialized text (~900 B/row; object.size() counts shared strings once)
  if (is.na(nb)) message("skipping b_chartbl: memory budget too small") else {
    b <- make_b(nb); message("b: ", format(object.size(b), units = "MB"))
    bench_object(b, "b_chartbl", names(M_ALL), nb, notes = sprintf("%s rows tibble, ~800 B text, uid chr, factor, Date", fmt_n(nb)))
    rm(b); gc()
  }
}
