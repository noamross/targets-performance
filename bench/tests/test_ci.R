# Tests for ci_results.R and ci_versions_diff.R against a throwaway git repo.
# Run from bench/: Rscript tests/test_ci.R   (base R; prints "ok" or stops)

rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
tmp <- tempfile("test-ci-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
sh <- function(...) {
  status <- system(paste(...), ignore.stdout = TRUE, ignore.stderr = TRUE)
  if (status != 0) stop("failed: ", paste(...))
}
put <- function(path, df) {
  path <- file.path(tmp, "repo", path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
}

# bench-results branch: two runs for one label
dir.create(file.path(tmp, "repo"))
sh("git -C", file.path(tmp, "repo"), "init -q -b bench-results")
timing <- function(a, b) {
  data.frame(
    topic = "fastfns",
    task = "sum",
    n = 100,
    method = c("a", "b"),
    median_s = c(a, b)
  )
}
put("runs/2026-01-01-aaaaaaa/linux-x64/fastfns/results/t.csv", timing(1, 2))
put("runs/2026-01-08-bbbbbbb/linux-x64/fastfns/results/t.csv", timing(3, 2))
put("latest/linux-x64/fastfns/results/t.csv", timing(3, 2))
put(
  "latest/linux-x64/ci/run_log.csv",
  data.frame(
    script = c("fastfns/x.R", "storage/y.R", "storage/z.R"),
    topic = c("fastfns", "storage", "storage"),
    status = c(0, 137, -1),
    killed = c("", "memory", ""),
    reason = c("", "", "needs 99 cores, have 4")
  )
)
writeBin(
  as.raw(0:255),
  file.path(tmp, "repo/latest/linux-x64/fastfns/results/bin.rds")
)
put("latest/versions.csv", data.frame(package = "x", version = "1"))
put(
  "index.csv",
  data.frame(
    run = c("2026-01-01-aaaaaaa", "2026-01-08-bbbbbbb"),
    label = "linux-x64",
    sha = "s",
    date = "d",
    files = 1
  )
)
sh("git -C", file.path(tmp, "repo"), "add -A")
sh(
  "git -C",
  file.path(tmp, "repo"),
  "-c user.name=t -c user.email=t@t commit -q -m x"
)

out <- file.path(tmp, "out")
res <- system2(
  rscript,
  c(
    "ci_results.R",
    paste0("repo=", file.path(tmp, "repo")),
    "ref=bench-results",
    "fetch=FALSE",
    paste0("out=", out)
  ),
  stdout = TRUE,
  stderr = TRUE
)
stopifnot(is.null(attr(res, "status")))
stopifnot(file.exists(file.path(out, "linux-x64/fastfns/results/t.csv")))
stopifnot(identical(
  readBin(file.path(out, "linux-x64/fastfns/results/bin.rds"), "raw", 300),
  as.raw(0:255)
))
stopifnot(!file.exists(file.path(out, "versions.csv")))
flags <- utils::read.csv(file.path(out, "flags.csv"), stringsAsFactors = FALSE)
stopifnot(
  setequal(flags$kind, c("failed", "median", "fastest")),
  flags$detail[flags$kind == "fastest"] == "a -> b",
  grepl("^a: ", flags$detail[flags$kind == "median"]),
  sum(flags$kind == "median") == 1,
  flags$reference[flags$kind == "failed"] == "storage-formats",
  sum(flags$kind == "failed") == 1
)

# ci_versions_diff.R
v <- data.frame(
  package = c("p", "q"),
  version = c("1.0", "2.0"),
  r_version = "4.6.2",
  platform = "x",
  tested = "d"
)
utils::write.csv(v, file.path(tmp, "v1.csv"), row.names = FALSE)
v$version[2] <- "2.1"
utils::write.csv(v, file.path(tmp, "v2.csv"), row.names = FALSE)
diff_out <- function(old, new) {
  gho <- file.path(tmp, "gho")
  unlink(gho)
  system2(
    rscript,
    c("ci_versions_diff.R", old, new),
    stdout = TRUE,
    env = paste0("GITHUB_OUTPUT=", gho)
  )
  readLines(gho)
}
stopifnot(
  diff_out(file.path(tmp, "v1.csv"), file.path(tmp, "v2.csv")) ==
    "changed=true",
  diff_out(file.path(tmp, "v1.csv"), file.path(tmp, "v1.csv")) ==
    "changed=false",
  diff_out(file.path(tmp, "none.csv"), file.path(tmp, "v1.csv")) ==
    "changed=true"
)
# run_suite.R: rows below min_cores / min_ram_gb are skipped (status -1), logged with a reason, not failed
suite <- data.frame(
  script = "fastfns/b6_identity.R", topic = "fastfns", args = "", cap_gb = 1,
  min_cores = 9999, min_ram_gb = NA, est_min = NA, ci = TRUE, needs = "", notes = ""
)
utils::write.csv(suite, file.path(tmp, "suite.csv"), row.names = FALSE)
rlog <- file.path(tmp, "rlog.csv")
res <- system2(
  rscript,
  c("run_suite.R", paste0("suite=", file.path(tmp, "suite.csv")), paste0("log=", rlog)),
  stdout = TRUE,
  stderr = TRUE
)
stopifnot(is.null(attr(res, "status")), any(grepl("1 skipped", res)))
lg <- utils::read.csv(rlog, stringsAsFactors = FALSE)
stopifnot(lg$status == -1, grepl("cores", lg$reason))
cat("ok\n")
