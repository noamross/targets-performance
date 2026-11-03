source("vectorize/_h.R")
f <- "vectorize/results/b4_pairs.csv"
pk <- c("purrr", "data.table", "kit", "vctrs", "dplyr")
nm <- function(x) as.numeric(unname(x))
set.seed(4)
for (n in c(1e3, 1e5, 1e6)) {
  a <- runif(n); b <- runif(n)
  slow <- n <= 1e5
  ex <- list(mapply_min = quote(mapply(min, a, b)), map2_dbl = quote(purrr::map2_dbl(a, b, min)),
    pmin = quote(pmin(a, b)), ifelse = quote(ifelse(a < b, a, b)), fifelse = quote(data.table::fifelse(a < b, a, b)),
    kit_iif = quote(kit::iif(a < b, a, b)), kit_pmin = quote(kit::pmin_(a, b)) )
  ex$kit_pmin <- NULL
  if (!slow) { ex$mapply_min <- quote(mapply(min, a[1:1e5], b[1:1e5])); ex$map2_dbl <- NULL }
  if (n == 1e6) { ex$mapply_min <- NULL }
  do.call(bm, c(list(task = "pairwise min", n = n, file = f, pkgs = pk, norm = nm, max_iter = 10, min_time = 0.3), ex))
  bm("pairwise min (map2 1e6 incl)", n, f, pk, norm = nm, map2_dbl = purrr::map2_dbl(a, b, min), pmin = pmin(a, b), max_iter = 5, min_time = 0.3)
  # vec_c / unlist combos: scalar results of list
  l <- as.list(a)
  bm("flatten list of scalars", n, f, pk, norm = nm, do_call_c = do.call(c, l), unlist = unlist(l), vec_c = vctrs::list_unchop(l), purrr_list_c = purrr::list_c(l), sapply_identity = sapply(l, identity))
  # categorical recode of two inputs
  cat3 <- sample(c("a", "b", "c"), n, TRUE)
  bm("recode 3 levels", n, f, pk, norm = function(z) as.character(unname(z)), sapply_switch = sapply(cat3, switch, a = "x", b = "y", c = "z", USE.NAMES = FALSE),
     case_when = dplyr::case_when(cat3 == "a" ~ "x", cat3 == "b" ~ "y", TRUE ~ "z"), fcase = data.table::fcase(cat3 == "a", "x", cat3 == "b", "y", default = "z"),
     lookup = c(a = "x", b = "y", c = "z")[cat3], match_idx = c("x", "y", "z")[match(cat3, c("a", "b", "c"))], max_iter = 15, min_time = 0.3)
}
