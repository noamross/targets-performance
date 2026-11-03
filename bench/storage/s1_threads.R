source("storage/_storage.R")
ms <- c("qs2_t1", "qs2_t4", "qd_t1", "qd_t4", "arrow_zstd", "arrow_zstd_1t", "duck_zstd", "duck_zstd_1t", "np_zstd")
if (fits_or_skip(150, 5, "a_numdf_threads")) { a <- make_a(2.5e6L); bench_object(a, "a_numdf_threads", ms, 2.5e6, notes = "thread comparison; 1t = arrow cpu/io threads 1 or duckdb SET threads=1"); rm(a); gc() }
if (fits_or_skip(150, 5, "b_chartbl_threads")) { b <- make_b(1.5e5L); bench_object(b, "b_chartbl_threads", ms, 1.5e5, notes = "thread comparison"); rm(b); gc() }
