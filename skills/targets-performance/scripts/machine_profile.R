# Report what this machine offers a {targets} pipeline: cores, memory,
# threading support per package, BLAS, thread env vars, container limits, disk.
# Usage: Rscript machine_profile.R [dir_for_disk_check=.]
# Read-only. Uses only base R plus optional packages when installed.

args <- commandArgs(trailingOnly = TRUE)
dir <- if (length(args)) args[[1]] else "."

has <- function(p) nzchar(system.file(package = p))
line <- function(label, value) cat(sprintf("%-26s %s\n", label, paste(value, collapse = " ")))
read1 <- function(f) if (file.exists(f)) trimws(readLines(f, n = 1, warn = FALSE)) else NA

# Machine ----
si <- Sys.info()
line("os / arch", c(si[["sysname"]], si[["release"]], R.version$arch))
line("R", R.version.string)
line("cores logical / physical", c(parallel::detectCores(), parallel::detectCores(logical = FALSE)))
if (has("parallelly")) line("cores available to R", parallelly::availableCores())

# df of a path without a shell pipeline: returns c(size_kb, avail_kb) or NULL (no df, e.g. Windows).
df_kb <- function(path) {
  if (!nzchar(Sys.which("df"))) return(NULL)
  out <- tryCatch(suppressWarnings(system2("df", c("-k", path), stdout = TRUE, stderr = FALSE)), error = function(e) NULL)
  if (length(out) < 2) return(NULL)
  f <- strsplit(trimws(out[[length(out)]]), "\\s+")[[1]]
  if (length(f) < 4) return(NULL)
  suppressWarnings(as.numeric(f[2:4]))[c(1, 3)]
}

# Memory ----
mem_gb <- function(x) sprintf("%.1f GB", x / 2^30)
if (has("ps")) {
  m <- ps::ps_system_memory()
  line("memory total / available", c(mem_gb(m$total), "/", mem_gb(m$avail)))
} else if (si[["sysname"]] == "Linux") {
  mi <- readLines("/proc/meminfo")
  kb <- function(k) as.numeric(sub("\\D+(\\d+).*", "\\1", grep(paste0("^", k, ":"), mi, value = TRUE))) * 1024
  line("memory total / available", c(mem_gb(kb("MemTotal")), "/", mem_gb(kb("MemAvailable"))))
} else {
  tot <- if (si[["sysname"]] == "Darwin" && nzchar(Sys.which("sysctl"))) {
    tryCatch(as.numeric(system2("sysctl", c("-n", "hw.memsize"), stdout = TRUE)), error = function(e) NA_real_, warning = function(w) NA_real_)
  } else NA_real_
  line("memory total", if (is.na(tot)) "unknown (install ps)" else mem_gb(tot))
  line("memory available", "install ps for available memory")
}

# Container / cgroup limits (Linux) ----
if (si[["sysname"]] == "Linux") {
  cg_mem <- read1("/sys/fs/cgroup/memory.max")
  cg_cpu <- read1("/sys/fs/cgroup/cpu.max")
  line("cgroup memory.max", cg_mem)
  line("cgroup cpu.max", cg_cpu)
  q <- suppressWarnings(as.numeric(strsplit(cg_cpu, " ")[[1]]))
  if (length(q) == 2 && !is.na(q[1])) {
    line("cpus allowed by cgroup", sprintf("%.1f (detectCores() ignores this; size NPROC and threads to it)", q[1] / q[2]))
  }
  if (has("parallelly")) line("parallelly::availableCores", parallelly::availableCores())
  line("in container", file.exists("/.dockerenv") || grepl("docker|containerd|kubepods", read1("/proc/1/cgroup")))
  shm <- df_kb("/dev/shm")
  line("/dev/shm (mori limit)", if (is.null(shm)) "unknown" else sprintf("%.1f GB total, %.1f GB free", shm[1] / 2^20, shm[2] / 2^20))
}

# Disk ----
disk <- df_kb(dir)
line("disk free at dir", if (is.null(disk)) "unknown (no df on this system)" else sprintf("%.1f GB (%s)", disk[2] / 2^20, normalizePath(dir)))

# Threading ----
cat("\nthreads (default in a fresh session; workers inherit env vars set before they start)\n")
env <- c("OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "R_DATATABLE_NUM_THREADS", "OPENBLAS_NUM_THREADS",
         "VECLIB_MAXIMUM_THREADS", "MKL_NUM_THREADS", "R_PARALLELLY_AVAILABLECORES_FALLBACK", "NPROC")
for (e in env) line(paste0("  $", e), ifelse(nzchar(Sys.getenv(e)), Sys.getenv(e), "-"))
if (has("data.table")) {
  out <- capture.output(data.table::getDTthreads(verbose = TRUE))
  omp <- any(grepl("omp_get_max_threads", out)) && !any(grepl("not compiled with OpenMP|OpenMP is not available", out, ignore.case = TRUE))
  line("  data.table", sprintf("%d threads, OpenMP %s", data.table::getDTthreads(), if (omp) "yes" else "NO"))
}
if (has("collapse")) line("  collapse", sprintf("nthreads %s (default 1)", collapse::get_collapse("nthreads")))
if (has("kit")) {
  # kit reports its OpenMP build when attached; timing tests give false positives.
  msg <- character(0)
  withCallingHandlers(suppressWarnings(library(kit)), packageStartupMessage = function(c) {
    msg <<- c(msg, conditionMessage(c))
    invokeRestart("muffleMessage")
  })
  omp_kit <- if (any(grepl("OPENMP enabled", msg))) "yes" else if (any(grepl("OPENMP disabled", msg))) "NO" else "unknown"
  line("  kit", sprintf("OpenMP %s, kit.nThread %s (default 1; set nThread= per call)", omp_kit, getOption("kit.nThread", 1)))
}
if (has("qs2")) line("  qs2", "nthreads arg / tar_resources_qs(); default 1")
if (has("arrow")) line("  arrow", sprintf("cpu %d, io %d", arrow::cpu_count(), arrow::io_thread_count()))
if (has("duckdb")) {
  con <- suppressMessages(DBI::dbConnect(duckdb::duckdb()))
  thr <- DBI::dbGetQuery(con, "SELECT current_setting('threads') AS t, current_setting('memory_limit') AS m")
  DBI::dbDisconnect(con, shutdown = TRUE)
  line("  duckdb", sprintf("threads %s, memory_limit %s, version %s", thr$t, thr$m, utils::packageVersion("duckdb")))
}
blas <- extSoftVersion()[["BLAS"]]
if (!nzchar(blas)) blas <- sessionInfo()$BLAS
# Linux: libblas.so.3 is an alternatives symlink; the mapped library shows the real one
# (directory names openblas-pthread / openblas-openmp / openblas-serial give the variant).
if (si[["sysname"]] == "Linux" && file.exists("/proc/self/maps")) {
  maps <- unique(sub("^.*\\s(/\\S+)$", "\\1", grep("blas|lapack|gomp", readLines("/proc/self/maps"), value = TRUE)))
  if (length(maps)) blas <- paste(maps, collapse = " ")
}
kind <- if (grepl("vecLib|Accelerate", blas)) "Accelerate (vecLib)" else
  if (grepl("openblas", blas, ignore.case = TRUE)) "OpenBLAS" else
  if (grepl("mkl", blas, ignore.case = TRUE)) "MKL" else
  if (grepl("libRblas", blas)) "R reference BLAS (single-threaded, slowest)" else "check path"
line("  BLAS", sprintf("%s: %s", kind, blas))
if (grepl("^R reference", kind)) {
  cat("    Optimized BLAS can speed up matrix-heavy code: see references/environment.md.\n")
}
if (kind == "OpenBLAS") {
  cat("    OpenBLAS threads default to all host CPUs: set OPENBLAS_NUM_THREADS and OMP_NUM_THREADS per worker.\n")
}
if (exists("cg_cpu") && has("data.table")) {
  q <- suppressWarnings(as.numeric(strsplit(cg_cpu, " ")[[1]]))
  if (length(q) == 2 && !is.na(q[1]) && data.table::getDTthreads() > q[1] / q[2]) {
    cat("    data.table uses more threads than the cgroup allows (it counts host CPUs): set R_DATATABLE_NUM_THREADS.\n")
  }
}

# Pipeline tooling ----
cat("\npackages\n")
for (p in c("targets", "tarchetypes", "crew", "mirai", "qs2", "mori", "nanoparquet", "arrow", "duckdb", "duckplyr",
            "collapse", "data.table", "kit", "Rfast", "stringi", "bench", "ps")) {
  line(paste0("  ", p), if (has(p)) as.character(utils::packageVersion(p)) else "-")
}
tools <- c("aria2c", "wget", "curl", "docker")
line("cli tools", paste0(tools, "=", ifelse(nzchar(Sys.which(tools)), "yes", "no")))

# Rough budget ----
cat("\nbudget hint: workers x peak RSS per worker + main process must fit in *available* memory,\n")
cat("and workers x threads per worker should not exceed physical cores.\n")
