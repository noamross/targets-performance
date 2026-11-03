#!/usr/bin/env bash
# In-container. Run from /work/bench. Each line: variant | env | workers | runtime-call
set -u
run() { v=$1; e=$2; w=$3; rt=$4; env $e B7_VARIANT=$v B7_WORKERS=$w B7_RT=$rt timeout 600 Rscript docker/b7_blas_workers.R 2>&1 | grep -E "wall|rror"; }
/work/bench/docker/blas_switch.sh pthread
run pthread OPENBLAS_NUM_THREADS=6 1 none
run pthread OPENBLAS_NUM_THREADS=6 3 none
run pthread OPENBLAS_NUM_THREADS=1 3 none
run pthread OPENBLAS_NUM_THREADS=2 3 none
run pthread X=1 3 none
run pthread X=1 3 blas1
run pthread X=1 3 blas2
run pthread X=1 3 omp1
/work/bench/docker/blas_switch.sh openmp
run openmp OMP_NUM_THREADS=6 1 none
run openmp OMP_NUM_THREADS=6 3 none
run openmp OMP_NUM_THREADS=1 3 none
run openmp OMP_NUM_THREADS=2 3 none
run openmp X=1 3 none
run openmp X=1 3 blas1
run openmp X=1 3 omp1
run openmp X=1 3 omp2
run openmp X=1 3 both2
