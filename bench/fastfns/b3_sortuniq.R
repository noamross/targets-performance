source("fastfns/_ff.R")
suppressMessages({library(data.table); library(collapse); library(kit)})
setDTthreads(1); set_collapse(nthreads = 1)
PK <- c("base", "data.table", "collapse", "kit", "Rfast")
cnt <- function(r) { if (is.data.frame(r)) { k <- as.character(r[[1]]); v <- r[[ncol(r)]] } else { k <- names(r); v <- unname(r) }
  o <- order(k, method = "radix"); list(k = k[o], v = as.numeric(v)[o]) }
set.seed(3)
pool_chr <- local({ p <- stringi::stri_rand_strings(2e5, 6, "[A-Za-z]"); unique(p) })
for (type in c("int", "dbl", "chr")) for (n in c(1e3, 1e5, if (type == "chr") 2e6 else 1e7)) {
  if (!fits_or_skip(n * 8 / 2^20, 10, sprintf("sortuniq n=%g %s", n, type))) next
  ng <- max(10, n / 10)
  x <- switch(type, int = sample.int(ng, n, TRUE), dbl = round(rnorm(n), 3), chr = sample(pool_chr[seq_len(min(ng, length(pool_chr)))], n, TRUE))
  tbl <- if (type == "dbl") unique(x)[seq_len(min(1e5, n))] else sample(unique(x), min(1e5, length(unique(x))))
  mi <- if (n >= 1e6) 3 else 10
  cat("\n#####", type, n, "\n")
  B <- function(task, e, norm = identity, notes = "") bm(e, n, paste0("su_", task, "_", type), "b3_sortuniq.csv", PK, norm = norm, max_it = mi, notes = notes)
  B("order", list(base = quote(order(x)), base_radix = quote(order(x, method = "radix")), forder = quote(data.table:::forder(x)),
                  collapse_radixorder = quote(radixorder(x)), Rfast_Order = quote(Rfast::Order(x)), Rfast_Order_stable = quote(Rfast::Order(x, stable = TRUE))))
  B("sort", list(base = quote(sort(x)), base_radix = quote(sort(x, method = "radix")), DT_forder_idx = quote(x[data.table:::forder(x)]),
                 collapse_idx = quote(x[radixorder(x)]), Rfast_Sort = quote(Rfast::Sort(x)), kit_psort = quote(psort(x))))
  B("unique", list(base = quote(unique(x)), collapse_funique = quote(funique(x)), kit_funique = quote(kit::funique(x)), DT_unique = quote(unique(as.data.table(x))[[1]]),
                   Rfast_sort_unique_SORTED = quote(Rfast::sort_unique(x))))
  B("uniqueN", list(base = quote(length(unique(x))), DT_uniqueN = quote(uniqueN(x)), collapse_fnunique = quote(fnunique(x)), kit_uniqLen = quote(uniqLen(x))))
  B("duplicated", list(base = quote(duplicated(x)), collapse_fduplicated = quote(fduplicated(x)), kit_fduplicated = quote(fduplicated(x))))
  B("match", c(list(base = quote(match(x, tbl)), collapse_fmatch = quote(fmatch(x, tbl))), if (type == "chr") list(DT_chmatch = quote(chmatch(x, tbl))), if (type != "chr") list(Rfast_Match_NOT_dropin = quote(Rfast::Match(x, tbl)))))
  B("in", c(list(base = quote(x %in% tbl), collapse_fmatch_in = quote(fmatch(x, tbl, nomatch = 0L) > 0L)), if (type == "chr") list(DT_chin = quote(x %chin% tbl))))
  B("count", c(list(base_table = quote(table(x)), collapse_qtab = quote(qtab(x)), collapse_fcount = quote(fcount(x)), kit_countOccur = quote(countOccur(x)),
                    DT_N_by = quote(as.data.table(x)[, .N, by = x])), if (type != "chr") list(Rfast_Table = quote(Rfast::Table(x))) else list()), norm = cnt,
    notes = "sorted by key then compared; class differs")
  rm(x, tbl); invisible(gc())
}
# locale trap
x <- c("b", "A", "a", "B", "_x", "Z", "z", "10", "9", "é", "e")
loc <- list(base = order(x), radix_C = order(x, method = "radix"), forder = data.table:::forder(x), radixorder = radixorder(x), fsort_dplyr = order(x, method = "radix"))
print(Sys.getlocale("LC_COLLATE")); print(lapply(loc, \(o) x[o]))
