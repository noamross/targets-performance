source("vectorize/_h.R")
f <- "vectorize/results/b5_text.csv"
pk <- c("stringi", "stringr", "purrr")
set.seed(5)
words <- stringi::stri_rand_strings(5000, sample(4:10, 5000, TRUE), "[a-z]")
mkdocs <- function(n, nw = 40) vapply(seq_len(n), function(i) paste(sample(words, nw, TRUE), collapse = " "), "")
for (n in c(1e3, 1e4, 1e5)) {
  if (!fits_or_skip(n * 300 / 2^20, 8, sprintf("b5 docs n=%g", n))) next
  docs <- mkdocs(n); terms <- sample(words, 200); t10 <- terms[1:10]
  nm <- function(x) as.numeric(unname(x))
  # any-term detection with 10 terms
  bm("any of 10 terms in text", n, f, pk, norm = nm,
     map_str_detect = Reduce(`|`, lapply(t10, \(t) stringr::str_detect(docs, stringr::fixed(t)))),
     map_stri_fixed = Reduce(`|`, lapply(t10, \(t) stringi::stri_detect_fixed(docs, t))),
     stri_fixed_outer = { r <- stringi::stri_detect_fixed(rep(docs, each = 10), rep(t10, times = n)); colSums(matrix(r, 10)) > 0 },
     stri_fixed_outer_loop = { m <- vapply(t10, \(t) stringi::stri_detect_fixed(docs, t), logical(n)); rowSums(m) > 0 },
     alternation_regex = stringi::stri_detect_regex(docs, paste(t10, collapse = "|")),
     base_grepl_fixed_loop = Reduce(`|`, lapply(t10, \(t) grepl(t, docs, fixed = TRUE))),
     per_doc_map = vapply(docs, \(d) any(stringi::stri_detect_fixed(d, t10)), NA, USE.NAMES = FALSE),
     max_iter = 10, min_time = 0.3)
  bm("count 200 terms (per-term totals)", n, f, pk, norm = nm,
     loop_count = vapply(terms, \(t) sum(stringi::stri_count_fixed(docs, t)), 0),
     one_collapsed_text = { big <- paste(docs, collapse = "\n"); vapply(terms, \(t) stringi::stri_count_fixed(big, t), 0L) } |> as.numeric(),
     max_iter = 5, min_time = 0.3)
  if (n <= 1e4) {
  dict <- terms; rep_ <- toupper(terms)
  bm("replace 200-term dictionary", n, f, pk, norm = nm,
     loop = { x <- docs; for (i in seq_along(dict)) x <- stringi::stri_replace_all_fixed(x, dict[i], rep_[i]); x },
     vectorize_all_FALSE = stringi::stri_replace_all_fixed(docs, dict, rep_, vectorize_all = FALSE),
     purrr_reduce = purrr::reduce2(dict, rep_, \(x, p, r) stringi::stri_replace_all_fixed(x, p, r), .init = docs),
     base_gsub_fixed_loop = { x <- docs; for (i in seq_along(dict)) x <- gsub(dict[i], rep_[i], x, fixed = TRUE); x },
     max_iter = 5, min_time = 0.3)
  }
}
