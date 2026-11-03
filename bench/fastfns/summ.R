# usage: summ.R file.csv [n] -> median_s and speedup vs 'base*' reference (first-listed baseline) per task/n
a <- commandArgs(TRUE); d <- read.csv(a[1])
if (length(a) > 1) d <- d[d$n == as.numeric(a[2]), ]
for (t in unique(d$task)) for (n in unique(d$n[d$task == t])) {
  s <- d[d$task == t & d$n == n, ]; s <- s[order(s$median_s), ]
  b <- s[grepl("^base", s$method), ]; ref <- if (nrow(b)) min(b$median_s) else NA
  cat(sprintf("%s n=%g | %s\n", t, n, paste(sprintf("%s %.3g%s%s%s", s$method, s$median_s * 1000, "ms", if (is.na(ref)) "" else sprintf(" (%.1fx)", ref / s$median_s), ifelse(s$identical_to_ref %in% TRUE, "", "!")), collapse = "; ")))
}
