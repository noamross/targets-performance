source("fastfns/_ff.R")
suppressMessages({library(data.table); library(collapse); library(dplyr); library(kit)})
setDTthreads(1); set_collapse(nthreads = 1)
PK <- c("base", "dplyr", "data.table", "collapse", "kit")
srt <- function(r) { r <- as.data.frame(r); r <- r[, order(names(r)), drop = FALSE]; r <- r[do.call(order, unname(as.list(r))), , drop = FALSE]; rownames(r) <- NULL; lapply(r, as.vector) }
## joins: x n rows, y n/10 rows unique key (m:1)
for (n in c(1e3, 1e5, 2e6)) {
  if (!fits_or_skip(n * 24 / 2^20, 10, sprintf("join n=%g", n))) next
  set.seed(4); ky <- seq_len(n / 10)
  x <- data.frame(k = sample(c(ky, n + 1:(n / 100)), n, TRUE), a = rnorm(n)); y <- data.frame(k = ky, b = runif(length(ky)))
  xd <- as.data.table(x); yd <- as.data.table(y)
  mi <- if (n >= 1e6) 3 else 10
  cat("\n## join", n, "\n")
  bm(list(dplyr = quote(left_join(x, y, by = "k")), DT = quote(yd[xd, on = "k"]), collapse = quote(collapse::join(x, y, on = "k", verbose = 0)),
          base_merge = quote(merge(x, y, by = "k", all.x = TRUE))),
     n, "join_left_m1", "b4_join.csv", PK, norm = srt, max_it = mi, notes = "unique y key")
  # duplicate keys in y: dup rows
  y2 <- rbind(y[seq_len(min(1000, nrow(y))), ], y[seq_len(min(1000, nrow(y))), ]); y2$b <- runif(nrow(y2)); yd2 <- as.data.table(y2)
  r_d <- left_join(x, y2, by = "k", multiple = "all"); r_c1 <- collapse::join(x, y2, on = "k", verbose = 0); r_c2 <- collapse::join(x, y2, on = "k", multiple = TRUE, verbose = 0)
  r_dt0 <- tryCatch(nrow(yd2[xd, on = "k"]), error = function(e) "ERROR allow.cartesian"); r_dt <- yd2[xd, on = "k", allow.cartesian = TRUE]
  rc <- data.frame(task = "join_dupkeys_rowcount", n = n, dplyr = nrow(r_d), DT_default = r_dt0, DT_allow_cartesian = nrow(r_dt), collapse_default = nrow(r_c1), collapse_multiple_TRUE = nrow(r_c2), x_rows = nrow(x))
  print(rc); write.table(rc, file.path(RES, "b4_join_rowcount.csv"), sep = ",", row.names = FALSE, col.names = !file.exists(file.path(RES, "b4_join_rowcount.csv")), append = file.exists(file.path(RES, "b4_join_rowcount.csv")))
  bm(list(dplyr = quote(left_join(x, y2, by = "k", multiple = "all")), DT = quote(yd2[xd, on = "k", allow.cartesian = TRUE]), collapse_multiple_TRUE = quote(collapse::join(x, y2, on = "k", multiple = TRUE, verbose = 0))),
     n, "join_left_dupkeys", "b4_join.csv", PK, norm = srt, max_it = mi, notes = "dup y keys")
  rm(x, y, y2, xd, yd, yd2, r_d, r_c1, r_c2, r_dt); invisible(gc())
}
## ifelse / case_when, lag
for (n in c(1e3, 1e5, 1e7)) {
  if (!fits_or_skip(n * 8 / 2^20, 10, sprintf("ifelse n=%g", n))) next
  set.seed(5); x <- rnorm(n); gg <- sort(sample.int(max(n / 100, 10), n, TRUE)); mi <- if (n >= 1e7) 3 else 10
  cat("\n## ifelse", n, "\n")
  bm(list(base_ifelse = quote(ifelse(x > 0, 1, -1)), dplyr_if_else = quote(if_else(x > 0, 1, -1)), DT_fifelse = quote(fifelse(x > 0, 1, -1)), kit_iif = quote(iif(x > 0, 1, -1))),
     n, "ifelse2", "b4_ifelse_lag.csv", PK, max_it = mi)
  bm(list(base_nested = quote(ifelse(x < -1, "lo", ifelse(x > 1, "hi", "mid"))), dplyr_case_when = quote(case_when(x < -1 ~ "lo", x > 1 ~ "hi", .default = "mid")),
          DT_fcase = quote(fcase(x < -1, "lo", x > 1, "hi", default = "mid")), kit_nif = quote(nif(x < -1, "lo", x > 1, "hi", default = "mid"))),
     n, "case3", "b4_ifelse_lag.csv", PK, max_it = mi)
  bm(list(base = quote(c(NA, x[-n])), dplyr_lag = quote(dplyr::lag(x)), DT_shift = quote(shift(x)), collapse_flag = quote(flag(x))),
     n, "lag_ungrouped", "b4_ifelse_lag.csv", PK, max_it = mi)
  d <- data.frame(g = gg, x = x); dt <- as.data.table(d)
  bm(list(dplyr = quote(mutate(d, l = dplyr::lag(x), .by = g)$l), DT = quote(dt[, shift(x), by = g]$V1), collapse_flag = quote(flag(x, g = gg)), base_ave = quote(ave(x, gg, FUN = function(v) c(NA, v[-length(v)])))),
     n, "lag_grouped", "b4_ifelse_lag.csv", PK, max_it = mi)
  bm(list(base_ave_cumsum = quote(ave(x, gg, FUN = cumsum)), dplyr = quote(mutate(d, c = cumsum(x), .by = g)$c), DT = quote(dt[, cumsum(x), by = g]$V1), collapse_fcumsum = quote(fcumsum(x, gg))),
     n, "cumsum_grouped", "b4_ifelse_lag.csv", PK, max_it = mi)
  rm(x, gg, d, dt); invisible(gc())
}
