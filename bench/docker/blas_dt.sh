#!/usr/bin/env bash
set -u
for v in pthread openmp; do
  /work/bench/docker/blas_switch.sh $v
  for e in "OPENBLAS_NUM_THREADS=6 OMP_NUM_THREADS=6" "OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=6" "OMP_NUM_THREADS=6" "X=1"; do
    env $e B7_VARIANT=$v timeout 300 Rscript docker/b7_blas_dt.R 2>&1 | grep -v "^$"; echo "  exit ${PIPESTATUS[0]}"
  done
done
