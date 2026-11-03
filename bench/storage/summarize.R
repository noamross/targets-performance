d <- read.csv("storage/results/storage.csv"); args <- commandArgs(TRUE)
d <- d[grepl(args[1], d$task), ]
w <- d[grepl("_write$", d$task), ]; r <- d[grepl("_read$", d$task), ]
key <- function(x) paste(sub("_(write|read)$", "", x$task), x$method)
m <- merge(transform(w, k = key(w))[, c("k", "median_s", "file_mb", "identical_to_ref", "equal_ignoring_attrs", "notes")],
           transform(r, k = key(r))[, c("k", "median_s")], by = "k", all = TRUE, suffixes = c("_w", "_r"))
m$notes <- ifelse(grepl("FAILED", m$notes), substr(m$notes, 1, 60), "")
names(m) <- c("task_method", "write_s", "file_mb", "ident", "eq_noattr", "fail", "read_s")
m[, c("write_s", "read_s")] <- lapply(m[, c("write_s", "read_s")], \(v) signif(v, 3))
print(m[order(m$task_method), c(1, 2, 7, 3, 4, 5, 6)], row.names = FALSE)
