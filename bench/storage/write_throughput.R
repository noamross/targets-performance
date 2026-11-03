# Write skills/targets-performance/format-throughput.csv: measured save/load speed per
# targets storage format, in MB of stored file per second, by object kind.
# Source: storage/results/storage.csv (B3). Run from bench/:
#   Rscript storage/write_throughput.R
d <- utils::read.csv("storage/results/storage.csv")
d <- d[grepl("_(write|read)$", d$task) & !grepl("threads", d$task) & !is.na(d$file_mb), ]
d$object <- sub("_(write|read)$", "", d$task)
d$op <- sub(".*_", "", d$task)
# targets format -> benchmark method closest to what that format does
fmt <- c(rds = "rds_gzip", qs = "qs2_t1", qs_4threads = "qs2_t4", parquet = "arrow_snappy",
         nanoparquet = "np_snappy", qdata = "qd_t1")
d <- d[d$method %in% fmt, ]
d$format <- names(fmt)[match(d$method, fmt)]
d$mb_per_s <- d$file_mb / d$median_s
w <- stats::reshape(d[, c("object", "format", "op", "mb_per_s", "file_mb", "n")],
                    idvar = c("object", "format"), timevar = "op", direction = "wide")
out <- data.frame(object = w$object, format = w$format, n = w$n.write, file_mb = round(w$file_mb.write, 1),
                  save_mb_per_s = round(w$mb_per_s.write, 1), load_mb_per_s = round(w$mb_per_s.read, 1),
                  source = "bench/storage/results/storage.csv", run_date = d$run_date[1])
out <- out[order(out$object, out$format), ]
utils::write.csv(out, "../skills/targets-performance/format-throughput.csv", row.names = FALSE)
print(out[, 1:6], row.names = FALSE)
