source("fastfns/_ff.R")
probe <- function() {
  library(data.table)
  list(pid = Sys.getpid(), OMP = Sys.getenv("OMP_NUM_THREADS", "<unset>"), RDT = Sys.getenv("R_DATATABLE_NUM_THREADS", "<unset>"),
       MYVAR = Sys.getenv("MYVAR", "<unset>"), dt_threads = data.table::getDTthreads(),
       dt_after_set1 = { data.table::setDTthreads(1); data.table::getDTthreads() })
}
vars <- c("OMP_NUM_THREADS", "R_DATATABLE_NUM_THREADS", "MYVAR")
rows <- list()
add <- function(engine, cond, r) rows[[length(rows) + 1]] <<- data.frame(engine = engine, condition = cond, OMP = r$OMP, RDT = r$RDT, MYVAR = r$MYVAR, dt_threads = r$dt_threads, dt_after_setDTthreads1 = r$dt_after_set1)
conds <- list(none = character(), RDT1_only = c(R_DATATABLE_NUM_THREADS = "1"), OMP1_only = c(OMP_NUM_THREADS = "1"),
              both_1_plus_MYVAR = c(OMP_NUM_THREADS = "1", R_DATATABLE_NUM_THREADS = "1", MYVAR = "hello"))
parent_dt <- NULL
for (cn in names(conds)) {
  Sys.unsetenv(vars); if (length(conds[[cn]])) do.call(Sys.setenv, as.list(conds[[cn]]))
  mirai::daemons(2)
  r <- mirai::mirai(probe(), probe = probe)[]
  mirai::daemons(0); add("mirai", cn, r)
  ctl <- crew::crew_controller_local(workers = 2, seconds_idle = 5)
  ctl$start(); ctl$push(command = probe(), data = list(probe = probe), name = "p"); ctl$wait(seconds_timeout = 60)
  res <- ctl$pop(); ctl$terminate()
  add("crew", cn, res$result[[1]])
}
# env set AFTER workers started
Sys.unsetenv(vars)
ctl <- crew::crew_controller_local(workers = 1, seconds_idle = 30); ctl$start()
ctl$push(command = probe(), data = list(probe = probe), name = "a"); ctl$wait(seconds_timeout = 60); ra <- ctl$pop()
Sys.setenv(MYVAR = "late", OMP_NUM_THREADS = "1", R_DATATABLE_NUM_THREADS = "1")
ctl$push(command = probe(), data = list(probe = probe), name = "b"); ctl$wait(seconds_timeout = 60); rb <- ctl$pop(); ctl$terminate()
add("crew", "env set after worker already running (same worker reused)", rb$result[[1]])
out <- do.call(rbind, rows); out$run_date <- format(Sys.Date()); out$parent_default_dt_threads <- { Sys.unsetenv(vars); data.table::getDTthreads() }
print(out)
write.csv(out, file.path(RES, "b6_envworkers.csv"), row.names = FALSE)
