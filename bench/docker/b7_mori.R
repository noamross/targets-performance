# mori share() of a 100 MB vector. Run with different --shm-size.
library(mori)
cat(system("df -m /dev/shm | tail -1", intern = TRUE), "\n")
x <- numeric(1.25e7)   # 100 MB
x[] <- runif(length(x))
r <- try(share(x), silent = TRUE)
if (inherits(r, "try-error")) cat("share() ERROR:", conditionMessage(attr(r, "condition")), "\n") else {
  cat("shared:", is_shared(r), " name:", shared_name(r), "\n")
  cat(system("df -m /dev/shm | tail -1", intern = TRUE), "\n")
  s <- sum(r); cat("sum ok", identical(s, sum(x)), "\n")
  cat(system("ls -la /dev/shm | head -5", intern = TRUE), sep = "\n")
}
