source("vectorize/_h.R")
library(stringi)
f <- "vectorize/results/b6_text_tricks.csv"
pk <- c("stringi")
set.seed(7)
V <- 3000
vocab <- stri_rand_strings(V, sample(3:10, V, TRUE), "[a-z]")
cap <- sample(V, 300); vocab[cap] <- stri_trans_totitle(vocab[cap])
nonascii <- c("café", "naïve", "straße", "ﬁnancial", "ﬂow", "İstanbul", "ΣAΣ", "Zürich", "œuvre", "déjà")
vocab[sample(V, length(nonascii))] <- nonascii
prob <- 1 / seq_len(V); prob <- prob / sum(prob)
mk_docs <- function(n, nw) do.call(stri_join, c(lapply(seq_len(nw), \(j) sample(vocab, n, TRUE, prob)), sep = " "))

# (5) unique then match, expensive per-string function, duplication 10/50/90%
n <- 1e5
check_fits(n * 80 / 2^20, 20, "titles")
pool_all <- mk_docs(n, 8)
slow_ascii <- \(x) stri_trans_general(x, "Any-Latin; Latin-ASCII")
slow_r <- \(x) vapply(x, \(s) paste(rev(strsplit(s, "")[[1]]), collapse = ""), "", USE.NAMES = FALSE)
for (dup in c(0.1, 0.5, 0.9)) {
  u <- max(1, round(n * (1 - dup))); pool <- pool_all[seq_len(u)]
  x <- c(pool, sample(pool, n - u, TRUE)); x <- sample(x)
  task <- sprintf("G5 unique-then-match, dup rate %d%%", round(dup * 100))
  bm(paste(task, "stri_trans_general"), n, f, pk, direct = slow_ascii(x), unique_match = { u_ <- unique(x); slow_ascii(u_)[match(x, u_)] },
     notes = sprintf("%d unique of %d", length(unique(x)), n), max_iter = 5, min_time = 0)
  bm(paste(task, "R-level per-string fn"), n, f, pk, direct = slow_r(x), unique_match = { u_ <- unique(x); slow_r(u_)[match(x, u_)] },
     notes = sprintf("%d unique of %d", length(unique(x)), n), max_iter = 5, min_time = 0)
}
rm(pool_all, pool, x); invisible(gc())

# (6) charclass vs regex; (9) to_ascii fast path
for (n in c(1e4, 5e4)) {
  check_fits(n * 1700 / 2^20, 8, "docs")
  docs <- mk_docs(n, 230)
  docs <- stri_replace_all_fixed(stri_replace_all_fixed(docs, "e", "e,"), "q", "q9")
  bm("G6 remove punct+digits: charclass vs regex", n, f, pk,
     regex = stri_replace_all_regex(docs, "[\\p{P}\\p{N}]", ""),
     charclass = stri_replace_all_charclass(docs, "[\\p{P}\\p{N}]", ""),
     regex_posix = stri_replace_all_regex(docs, "[[:punct:][:digit:]]", ""),
     max_iter = 10, min_time = 0.5)
  bm("G6 remove single char ',': fixed vs charclass vs regex", n, f, pk,
     regex = stri_replace_all_regex(docs, ",", ""), fixed = stri_replace_all_fixed(docs, ",", ""),
     charclass = stri_replace_all_charclass(docs, "[,]", ""), base_gsub = gsub(",", "", docs, fixed = TRUE),
     max_iter = 10, min_time = 0.5)
  bm("G6 collapse whitespace runs: charclass vs regex", n, f, pk,
     regex = stri_replace_all_regex(docs, "\\s+", " "), regex_trim = stri_trim_both(stri_replace_all_regex(docs, "\\s{2,}", " ")),
     charclass_merge = stri_replace_all_charclass(docs, "\\p{WHITE_SPACE}", " ", merge = TRUE),
     max_iter = 10, min_time = 0.5)
  tab_from <- c("ï", "é", "à", "ü", "ß", "ﬁ", "ﬂ", "İ", "œ")
  tab_to <- c("i", "e", "a", "u", "ss", "fi", "fl", "I", "oe")
  full <- \() stri_trans_general(docs, "Any-Latin; Latin-ASCII")
  fast <- \() { x <- stri_replace_all_fixed(docs, tab_from, tab_to, vectorize_all = FALSE)
    bad <- !stri_enc_isascii(x); x[bad] <- stri_trans_general(x[bad], "Any-Latin; Latin-ASCII"); x }
  fast_noscan <- \() stri_replace_all_fixed(docs, tab_from, tab_to, vectorize_all = FALSE)
  a <- full(); b <- fast()
  bm("G9 to_ascii: fixed table first, trans only on remaining", n, f, pk, trans_general_all = full(), fixed_then_trans_on_remaining = fast(),
     notes = sprintf("docs non-ASCII initially %d of %d; still non-ASCII after table %d; mismatches %d", sum(!stri_enc_isascii(docs)), n, sum(!stri_enc_isascii(fast_noscan())), sum(a != b)),
     max_iter = 3, min_time = 0)
  cat("G9 n", n, "mismatch docs", sum(a != b), "\n")
  rm(docs, a, b); invisible(gc())
}
