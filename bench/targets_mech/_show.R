args <- commandArgs(TRUE); d <- read.csv(args[1])
cols <- intersect(c("n","wall_s","sum_meta_s","loads","load_s","peak_rss_mb","sys_peak_mb"), names(d))
d$method <- sub("storage/retrieval=", "pl=", d$method)
for (c in cols) d[[c]] <- round(d[[c]], 1)
for (i in seq_len(nrow(d))) cat(sprintf("[%02d] %s %s%s => %s\n", i, if (length(args) > 1) paste0(d$task[i], " ") else "", d$method[i], if (grepl("KILLED", d$notes[i])) " (KILLED)" else "",
  paste(paste0(cols, "=", unlist(d[i, cols])), collapse = ", ")))
