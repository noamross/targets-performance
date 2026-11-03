#!/usr/bin/env bash
# In-container (libopenblas.so.0 must switch too: libblas.so.3 finds it via $ORIGIN): select the system BLAS/LAPACK. Usage: blas_switch.sh reference|serial|pthread|openmp
set -eu
case $1 in
  reference) d=blas; l=lapack ;;
  serial|pthread|openmp) d=openblas-$1; l=openblas-$1 ;;
  *) echo "unknown variant $1" >&2; exit 1 ;;
esac
a=/usr/lib/aarch64-linux-gnu
update-alternatives --quiet --set libblas.so.3-aarch64-linux-gnu $a/$d/libblas.so.3
[ "$1" = reference ] || update-alternatives --quiet --set libopenblas.so.0-aarch64-linux-gnu $a/$d/libopenblas.so.0
update-alternatives --quiet --set liblapack.so.3-aarch64-linux-gnu $a/$l/liblapack.so.3
