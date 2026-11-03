#!/usr/bin/env bash
# In-container: thread-env matrix over BLAS variants. Run from /work/bench.
set -u
for v in reference serial pthread openmp; do
  /work/bench/docker/blas_switch.sh $v
  if [ $v = reference ]; then envs=("X=1"); else envs=("OPENBLAS_NUM_THREADS=1" "OPENBLAS_NUM_THREADS=6" "OMP_NUM_THREADS=1" "OMP_NUM_THREADS=6" "X=1"); fi
  for e in "${envs[@]}"; do
    env "$e" B7_VARIANT=$v Rscript docker/b7_blas.R 2>&1 | grep -v "^$"
  done
done
