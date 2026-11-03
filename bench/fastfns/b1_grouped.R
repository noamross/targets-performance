source("fastfns/_ff.R")
suppressMessages({library(data.table); library(collapse); library(dplyr)})
setDTthreads(1); set_collapse(nthreads = 1)
PK <- c("base", "dplyr", "data.table", "collapse", "Rfast")
args <- commandArgs(TRUE)
ns <- if (length(args)) as.numeric(args) else c(1e3, 1e5, 1e7)
pool <- paste0("key_", sprintf("%07d", 1:1e6))
for (n in ns) for (G in c("few", "many")) for (kt in strsplit(Sys.getenv("KT", "int,chr"), ",")[[1]]) {
  ng <- if (G == "few") 10L else as.integer(max(n / 10, 100))
  if (!fits_or_skip(n * 8 / 2^20 * (if (kt == "chr") 2 else 1), 50, sprintf("grouped n=%g %s %s", n, G, kt))) next
  set.seed(1)
  gi <- sample.int(ng, n, replace = TRUE)
  g <- if (kt == "int") gi else pool[gi]
  x <- rnorm(n)
  d <- data.frame(g = g, x = x); dt <- as.data.table(d)
  gr <- collapse::GRP(g)
  mi <- if (n >= 1e7) 3 else 10
  slow_ok <- !(n >= 1e7 && G == "many")      # base aggregate/tapply impractical
  cat("\n#####", n, G, kt, "\n")
  mk <- function(stat, ...) {
    e <- list(...)
    bm(e, n, sprintf("grouped_%s_%s_%s", stat, kt, G), "b1_grouped.csv", PK, norm = canon, max_it = mi)
  }
  # sum
  e <- list(
    dplyr = quote(summarise(d, v = sum(x), .by = g)),
    DT = quote(dt[, .(v = sum(x)), by = g]),
    collapse = quote(fsum(x, g)),
    collapse_GRP = quote(fsum(x, gr)),
    collapse_nosort = quote(fsum(x, g, sort = FALSE))
  )
  if (slow_ok) { e <- c(list(base_rowsum = quote(rowsum(x, g)), base_tapply = quote(tapply(x, g, sum)), base_aggregate = quote(aggregate(x ~ g, d, sum))), e) }
  else e <- c(list(base_rowsum = quote(rowsum(x, g))), e)
  if (kt == "int") e$Rfast_group <- quote(Rfast::group(x, g, method = "sum"))
  e <- e[c(grep("base_rowsum", names(e)), setdiff(seq_along(e), grep("base_rowsum", names(e))))]
  bm(e, n, sprintf("grouped_sum_%s_%s", kt, G), "b1_grouped.csv", PK, norm = canon, max_it = mi)
  # mean
  e <- list(
    base_rowsum_div = quote({s <- rowsum(x, g); s[, 1] / as.vector(table(g)[rownames(s)])}),
    dplyr = quote(summarise(d, v = mean(x), .by = g)),
    DT = quote(dt[, .(v = mean(x)), by = g]),
    collapse = quote(fmean(x, g)),
    collapse_GRP = quote(fmean(x, gr))
  )
  if (slow_ok) e <- c(e, list(base_tapply = quote(tapply(x, g, mean))))
  if (kt == "int") e$Rfast_group <- quote(Rfast::group(x, g, method = "mean"))
  e <- e[-1]  # drop awkward manual rowsum mean; tapply is the base reference
  if (!slow_ok) e <- c(list(base_tapply = quote(tapply(x, g, mean))), e)
  else e <- e[c("base_tapply", setdiff(names(e), "base_tapply"))]
  bm(e, n, sprintf("grouped_mean_%s_%s", kt, G), "b1_grouped.csv", PK, norm = canon, max_it = mi)
  # median
  e <- list(
    dplyr = quote(summarise(d, v = median(x), .by = g)),
    DT = quote(dt[, .(v = median(x)), by = g]),
    collapse = quote(fmedian(x, g)),
    collapse_GRP = quote(fmedian(x, gr))
  )
  if (slow_ok) e <- c(list(base_tapply = quote(tapply(x, g, median))), e)
  else e <- c(list(DT = e$DT), e[names(e) != "DT"])  # DT as reference when base too slow
  if (kt == "int") e$Rfast_group <- quote(Rfast::group(x, g, method = "median"))
  bm(e, n, sprintf("grouped_median_%s_%s", kt, G), "b1_grouped.csv", PK, norm = canon, max_it = mi)
  # quantile 0.9
  e <- list(
    dplyr = quote(summarise(d, v = quantile(x, 0.9), .by = g)),
    DT = quote(dt[, .(v = quantile(x, 0.9)), by = g]),
    collapse_fnth = quote(fnth(x, 0.9, g)),
    collapse_fnth_GRP = quote(fnth(x, 0.9, gr))
  )
  if (slow_ok) e <- c(list(base_tapply = quote(tapply(x, g, quantile, 0.9))), e)
  else e <- c(list(collapse_fnth = e$collapse_fnth), e[names(e) != "collapse_fnth"])
  if (n >= 1e7 && G == "many") e <- e[!names(e) %in% c("dplyr", "DT")]
  bm(e, n, sprintf("grouped_quantile90_%s_%s", kt, G), "b1_grouped.csv", PK, norm = canon, max_it = mi)
  rm(d, dt, x, g, gi, gr); invisible(gc())
}
