#!/bin/sh
# Mean/min wall seconds of `Rscript -e 1` in an renv project under startup settings.
# Usage: sh startup/renv_startup.sh <renv-project-dir>   (reads only; run on a scratch project)
cd "$1" || exit 1
t(){ for i in 1 2 3 4 5 6 7 8 9 10; do /usr/bin/time -p env "$@" Rscript -e 1 2>&1 | grep real; done |
  awk -v l="$*" '{s+=$2; if(NR==1||$2<m)m=$2} END {printf "%s mean=%.3f min=%.3f\n", l, s/NR, m}'; }
t X=1; t RENV_CONFIG_SYNCHRONIZED_CHECK=FALSE; t RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
(cd /tmp && t X=1)
