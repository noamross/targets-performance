# Case 3: memory = transient / persistent / auto, storage/retrieval main vs worker, serial vs NPROC=3.
# big = numeric data frame (10 cols) of BIG_MB, read by 6 consumers (each makes a ~90 MB matrix + temp).
# 300 MB: serial + worker placement (main placement exceeds 4 GB at NPROC=3 -> recorded as KILLED);
# 100 MB: every config, to show scaling.
source("targets_mech/_tm.R")
OUT <- "targets_mech/results/c3_memory.csv"
pipe <- function(mb, ...) paste(tm_prelude(...), sprintf('
big_t <- tar_target(big, make_big(%d), format = fmt_logged)
cons <- lapply(1:6, function(i) tar_target_raw(paste0("c", i), substitute(consume(big, I), list(I = i)), format = "rds"))
c(list(big_t), cons, list(tar_target(final, sum(c1, c2, c3, c4, c5, c6), memory = "transient")))', mb), sep = "\n")
rows <- list()
go <- function(mb, nproc, mem, plc) {
  if (!tm_fits(mb * (2 + 2 * nproc), sprintf("c3 %g MB nproc %d", mb, nproc))) return(invisible())
  message("running ", mb, " ", nproc, " ", mem, " ", plc)
  r <- if (plc == "auto") tm_run("c3", pipe(mb, nproc, memory = mem, storage = "worker", retrieval = "auto"))
       else tm_run("c3", pipe(mb, nproc, memory = mem, storage = plc, retrieval = plc))
  rows[[length(rows) + 1]] <<- tm_row(sprintf("big%d_6consumers", mb), mb,
    if (nproc == 1) sprintf("serial memory=%s storage/retrieval=%s", mem, plc) else sprintf("nproc=%d memory=%s storage/retrieval=%s", nproc, mem, plc), r)
}
# plc "auto" = storage "worker" + retrieval "auto" (targets >= 1.11 default). Args: MBs (comma list) and placements (comma list).
args <- commandArgs(TRUE)
MBS <- as.numeric(strsplit(if (length(args) >= 1) args[1] else "300,100", ",")[[1]])
PLCS <- strsplit(if (length(args) >= 2) args[2] else "worker,main,auto", ",")[[1]]
for (mb in MBS) for (mem in c("transient", "persistent", "auto")) {
  for (plc in PLCS) go(mb, 1, mem, plc)
  for (plc in PLCS) if (!(mb == 300 && plc == "main")) go(mb, NP3, mem, plc)
}
tm_save(do.call(rbind, rows), OUT)
