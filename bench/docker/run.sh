#!/usr/bin/env bash
# Run a command in the benchmark container with explicit limits. Local only.
# Usage: bench/docker/run.sh <mem> <cpus> <shm> <cmd...>   e.g. run.sh 4g 6 64m Rscript fastfns/x.R
# R_ENVIRON_USER stops the host rig .Renviron (macOS library) loading in the container.
# Mounts: repo bench/ (rw) at /work/bench, skills/ (ro) at /work/skills, scratch at /scratch.
set -eu
repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="${B7_SCRATCH:-${BENCH_SCRATCH:-${TMPDIR:-/tmp}/targets-performance-bench}/b7}"
mkdir -p "$scratch"; : > "$scratch/empty.Renviron"
mem=$1; cpus=$2; shm=$3; shift 3
docker run --rm --memory="$mem" --memory-swap="$mem" --cpus="$cpus" --shm-size="$shm" \
  -v "$repo/bench:/work/bench" -v "$repo/skills:/work/skills:ro" -v "$scratch:/scratch" \
  -e R_ENVIRON_USER=/scratch/empty.Renviron -w /work/bench ${B7_ENV:+$B7_ENV} targets-performance-b7:local "$@"
