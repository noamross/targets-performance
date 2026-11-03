# One tiny live call: curl::multi_download of two small public CRAN index files.
# Run: cd bench && Rscript startup/multi_download_test.R <out_dir>
out <- commandArgs(TRUE)[1]
urls <- c("https://cloud.r-project.org/src/contrib/PACKAGES.gz",
          "https://cloud.r-project.org/src/contrib/PACKAGES.rds")
t <- system.time(res <- curl::multi_download(urls, file.path(out, basename(urls)), progress = FALSE))
print(res[, c("url", "success", "status_code", "resumefrom", "time")]); print(file.size(res$destfile))
cat("elapsed", t[["elapsed"]], "curl", as.character(packageVersion("curl")), "httr2", as.character(packageVersion("httr2")), "\n")
