FROM rocker/r-ver:4.6.2
RUN Rscript -e 'install.packages(c("data.table","collapse","kit","Rfast","qs2","arrow","duckdb","nanoparquet","bench","ps","targets","crew","mirai","mori"), Ncpus = 6)' \
 && Rscript -e 'stopifnot(all(c("data.table","collapse","kit","Rfast","qs2","arrow","duckdb","nanoparquet","bench","ps","targets","crew","mirai","mori") %in% rownames(installed.packages())))'
WORKDIR /work/bench
RUN apt-get update && apt-get install -y --no-install-recommends libopenblas0-openmp libopenblas0-serial && rm -rf /var/lib/apt/lists/* \
 && Rscript -e 'install.packages(c("RhpcBLASctl","parallelly"), Ncpus = 6)'
