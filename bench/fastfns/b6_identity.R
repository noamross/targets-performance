source("fastfns/_ff.R")
suppressMessages({library(data.table); library(collapse); library(dplyr)})
setDTthreads(1)
out <- list(); chk <- function(id, section, claim, result, detail = "") out[[length(out) + 1]] <<- data.frame(id = id, section = section, claim = claim, result = as.character(result), detail = detail)
n <- 1e6; check_fits(n * 8 / 2^20, 10, "identity")
# (b) fmean vs mean, fsum vs sum
res <- vapply(1:20, \(s) { set.seed(s); x <- rnorm(n); c(mean = identical(fmean(x), mean(x)), sum = identical(fsum(x), sum(x)),
  mean_ae = isTRUE(all.equal(fmean(x), mean(x))), maxdiff = abs(fmean(x) - mean(x))) }, numeric(4))
chk("b_fmean", "6b", "fmean(x) identical to mean(x), 20 seeds of rnorm(1e6)", sprintf("%d/20 identical; all.equal %d/20", sum(res["mean", ]), sum(res["mean_ae", ])), sprintf("max abs diff %.3g", max(res["maxdiff", ])))
chk("b_fsum", "6b", "fsum(x) identical to sum(x), 20 seeds", sprintf("%d/20 identical", sum(res["sum", ])))
x <- c(1:10 + 0.1); chk("b_fmean_small", "6b", "fmean vs mean on x=1:10+0.1", identical(fmean(x), mean(x)))
# grouped identity vs base tapply, many seeds
set.seed(7); g <- sample.int(1e3, n, TRUE); x <- rnorm(n)
gi <- function(f1, f2) { a <- f1(); b <- f2(); c(identical = identical(unname(as.numeric(a)), unname(as.numeric(b))), all.equal = isTRUE(all.equal(unname(as.numeric(a)), unname(as.numeric(b)))), maxdiff = max(abs(as.numeric(a) - as.numeric(b)))) }
tp <- \(f, ...) tapply(x, g, f, ...)
for (nm in c("sum", "mean", "median", "q90")) {
  base <- switch(nm, sum = \() tp(sum), mean = \() tp(mean), median = \() tp(median), q90 = \() tp(quantile, 0.9))
  cands <- list(collapse = switch(nm, sum = \() fsum(x, g), mean = \() fmean(x, g), median = \() fmedian(x, g), q90 = \() fnth(x, 0.9, g)),
    data.table = switch(nm, sum = \() as.data.table(list(g = g, x = x))[, sum(x), keyby = g]$V1, mean = \() data.table(g = g, x = x)[, mean(x), keyby = g]$V1,
      median = \() data.table(g = g, x = x)[, median(x), keyby = g]$V1, q90 = \() data.table(g = g, x = x)[, quantile(x, .9), keyby = g]$V1),
    Rfast = switch(nm, sum = \() Rfast::group(x, g, "sum"), mean = \() Rfast::group(x, g, "mean"), median = \() Rfast::group(x, g, "median"), q90 = NULL))
  for (cn in names(cands)) if (!is.null(cands[[cn]])) { r <- gi(base, cands[[cn]]); chk(paste0("grp_", nm, "_", cn), "1", sprintf("grouped %s: %s vs base tapply (1e6 rows, 1e3 groups)", nm, cn), sprintf("identical=%s all.equal=%s", r[["identical"]], r[["all.equal"]]), sprintf("max abs diff %.3g", r[["maxdiff"]])) }
}
# matrix
m <- matrix(rnorm(1e6), 1e4, 100)
for (p in list(list("colMeans", \() colMeans(m), \() collapse::fmean(m), \() Rfast::colmeans(m)), list("colSums", \() colSums(m), \() collapse::fsum(m), \() Rfast::colsums(m)),
               list("colVar", \() apply(m, 2, var), \() collapse::fvar(m), \() Rfast::colVars(m)))) {
  b <- p[[2]](); for (i in 3:4) { r <- p[[i]](); chk(paste0("mat_", p[[1]], "_", c("", "", "collapse", "Rfast")[i]), "2", sprintf("%s: %s vs base", p[[1]], c("", "", "collapse", "Rfast")[i]),
    sprintf("identical=%s all.equal=%s", identical(unname(b), unname(as.vector(r))), isTRUE(all.equal(unname(b), unname(as.vector(r))))), sprintf("attributes: base names=%s; fast names=%s", !is.null(names(b)), !is.null(names(r)))) } }
# join DT vs dplyr
set.seed(4); xx <- data.frame(k = sample(1:2000, 1e4, TRUE), a = rnorm(1e4)); yy <- data.frame(k = 1:1000, b = runif(1000))
a <- left_join(xx, yy, by = "k"); b <- as.data.frame(as.data.table(yy)[as.data.table(xx), on = "k"]); cj <- collapse::join(xx, yy, on = "k", verbose = 0)
chk("join_dt_cols", "4", "left join DT yd[xd,on=] column order vs dplyr", paste(names(b), collapse = ","), paste("dplyr:", paste(names(a), collapse = ",")))
chk("join_dt_rows", "4", "DT join after reordering columns equals dplyr (row order kept)", isTRUE(all.equal(a, b[, names(a)], check.attributes = FALSE)))
chk("join_collapse_equal", "4", "collapse::join identical to dplyr left_join (unique y key)", identical(a, cj))
# NA semantics
chk("na_fsum", "pitfall", "fsum(c(NA,NA)) vs sum", sprintf("fsum=%s sum=%s", format(fsum(c(NA_real_, NA))), format(sum(c(NA_real_, NA)))))
chk("na_fsum_na_rm", "pitfall", "fsum(c(NA,1)) / mean", sprintf("fsum=%s sum=%s fmean=%s mean=%s", fsum(c(NA, 1)), sum(c(NA, 1)), fmean(c(NA, 1)), mean(c(NA, 1))))
gg <- c(1, 1, 2, 2); xv <- c(NA, NA, 1, 2)
chk("na_allNA_group", "pitfall", "all-NA group mean: base tapply vs fmean vs dplyr(na.rm=TRUE)", sprintf("tapply(na.rm)=%s fmean=%s dplyr=%s", paste(tapply(xv, gg, mean, na.rm = TRUE), collapse = ","), paste(fmean(xv, gg), collapse = ","), paste(summarise(data.frame(g = gg, x = xv), v = mean(x, na.rm = TRUE), .by = g)$v, collapse = ",")))
chk("na_fcumsum", "pitfall", "fcumsum(c(1,NA,3)) vs cumsum", sprintf("fcumsum=%s cumsum=%s", paste(fcumsum(c(1, NA, 3)), collapse = ","), paste(cumsum(c(1, NA, 3)), collapse = ",")))
chk("int_overflow", "pitfall", "grouped fsum integer overflow", tryCatch({ fsum(rep(.Machine$integer.max, 3), c(1, 1, 1)); "no error" }, error = \(e) conditionMessage(e), warning = \(w) paste("warning:", conditionMessage(w))), "base tapply: NA with warning")
chk("kit_iif_types", "5", "kit::iif(c(TRUE,FALSE), 1L, 2) type mix", tryCatch(class(kit::iif(c(TRUE, FALSE), 1L, 2)), error = \(e) paste("ERROR:", conditionMessage(e))), "fifelse: " )
chk("fifelse_types", "5", "fifelse(c(TRUE,FALSE), 1L, 2)", tryCatch(class(fifelse(c(TRUE, FALSE), 1L, 2)), error = \(e) paste("ERROR:", conditionMessage(e))))
chk("ifelse_date", "5", "base ifelse drops Date class; fifelse keeps", sprintf("base=%s fifelse=%s", class(ifelse(TRUE, Sys.Date(), Sys.Date())), class(fifelse(TRUE, Sys.Date(), Sys.Date()))))
# (c) Rfast RNG
set.seed(1); a <- rnorm(5); set.seed(1); b <- Rfast::Rnorm(5); set.seed(1); b2 <- Rfast::Rnorm(5); b3 <- Rfast::Rnorm(5, seed = 1)
chk("rfast_rng", "6c", "Rfast::Rnorm after set.seed(1) vs stats::rnorm", sprintf("identical to rnorm: %s; reproducible under set.seed: %s; Rnorm(seed=1) == set.seed-run: %s", identical(a, b), identical(b, b2), identical(b3, b)), paste("rnorm:", paste(round(a, 3), collapse = " "), "| Rnorm:", paste(round(b, 3), collapse = " ")))
set.seed(1); s1 <- sample(10); set.seed(1); s2 <- Rfast::colShuffle(matrix(1:10, 10, 1))[, 1]
chk("rfast_shuffle", "6c", "Rfast::colShuffle after set.seed(1) vs sample(10)", sprintf("identical: %s", identical(as.integer(s1), as.integer(s2))))
set.seed(1); r1 <- Rfast::Rnorm(3); set.seed(2); r2 <- Rfast::Rnorm(3); chk("rfast_rng_seed_sensitive", "6c", "Rfast::Rnorm responds to set.seed (different seeds differ)", !identical(r1, r2))
# (7) masking, last: mutates search path
d <- data.frame(g = c(1, 1, 2, 2), x = c(1, NA, 3, 4))
before <- summarise(d, s = sum(x), m = mean(x), .by = g); chk("mask_before", "7", "dplyr summarise(sum(x), mean(x), .by=g) with NA", paste0("sum=", paste(before$s, collapse = ","), " mean=", paste(before$m, collapse = ",")))
collapse::set_collapse(mask = "all")
after <- summarise(d, s = sum(x), m = mean(x), .by = g)
chk("mask_after_all", "7", "same after set_collapse(mask='all') (dplyr verb unchanged, sum->fsum)", paste0("sum=", paste(after$s, collapse = ","), " mean=", paste(after$m, collapse = ",")), "na.rm=TRUE default now applies silently")
dd <- data.frame(g = c("b", "a", "b", "a", "c"), x = 1:5)
chk("mask_order", "7", "group order: dplyr .by (first appearance) before/after mask", paste(summarise(dd, s = sum(x), .by = g)$g, collapse = ","), "base tapply order: a,b,c")
chk("mask_fsum_default_sort", "7", "collapse::fsum(x, g) group order default", paste(names(fsum(dd$x, dd$g)), collapse = ","), "sort=TRUE default; dplyr .by keeps appearance order")
r <- do.call(rbind, out); write.csv(r, file.path(RES, "b6_identity.csv"), row.names = FALSE); print(r[, c("id", "result")], right = FALSE)
