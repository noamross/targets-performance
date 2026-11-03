a <- commandArgs(TRUE); d <- read.csv(a[1])
for (k in unique(d$task)) { x <- d[d$task == k, ]; cat(k, "|", paste0(x$method, "=", signif(x$median_s*1000, 3), "ms", ifelse(x$identical_to_ref %in% TRUE, "", "(NOTID)"), collapse = "; "), "\n") }
