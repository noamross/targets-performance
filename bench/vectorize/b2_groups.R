source("vectorize/_h.R")
library(data.table)
f <- "vectorize/results/b2_groups.csv"
pk <- c("collapse", "data.table", "dplyr", "purrr")
T4 <- min(4L, bench_cores()); dt0 <- getDTthreads(); cl0 <- collapse::get_collapse()$nthreads
nm <- function(x) round(as.numeric(unlist(x, use.names = FALSE)), 8)
set.seed(2)
for (n in c(1e3, 1e5, 1e6)) for (k in c(10, n / 10)) {
  if (k < 10) next
  g <- sample.int(k, n, TRUE); x <- runif(n); d <- data.frame(g = g, x = x); dt <- as.data.table(d)
  task <- sprintf("group mean, %g rows, %g groups", n, k)
  ex <- list(
    split_lapply = quote(sort_by_g(lapply(split(x, g), mean))),
    tapply = quote(tapply(x, g, mean)),
    split_df_map = quote(purrr::map_dbl(split(d, d$g), \(s) mean(s$x))),
    rowsum_tabulate = quote(rowsum(x, g)[, 1] / tabulate(g)[sort(unique(g))]),
    collapse_fmean = quote(collapse::fmean(x, g)),
    collapse_fmean_GRP = quote(collapse::fmean(x, collapse::GRP(g))),
    dt_by = quote(dt[, .(m = mean(x)), keyby = g]$m),
    dplyr_by = quote(dplyr::arrange(dplyr::summarise(d, m = mean(x), .by = g), g)$m)
  )
  if (n * (k / 10) > 1e7 || k > 1e5) ex$split_df_map <- NULL
  sort_by_g <- function(l) l[order(as.integer(names(l)))]
  setDTthreads(dt0); collapse::set_collapse(nthreads = cl0)
  args <- c(list(task = task, n = n, file = f, pkgs = pk, norm = nm, notes = sprintf("DTthreads=%d collapse nthreads=%d", dt0, cl0)), ex)
  do.call(bm, args)
  setDTthreads(1); collapse::set_collapse(nthreads = 1)
  bm(task, n, f, pk, dt_by_1thread = dt[, .(m = mean(x)), keyby = g]$m,
     collapse_fmean_1thread = collapse::fmean(x, g), norm = nm, notes = "DTthreads=1 collapse nthreads=1")
  if (T4 >= 2) {
    collapse::set_collapse(nthreads = T4)
    do.call(bm, setNames(list(task, n, f, pk, quote(collapse::fmean(x, g, nthreads = T4)), nm, sprintf("collapse nthreads=%d", T4)),
      c("", "", "", "", sprintf("collapse_fmean_%dthreads", T4), "norm", "notes")))
  }
  setDTthreads(dt0)
}
