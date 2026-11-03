source("vectorize/_h.R")
library(stringi)
f <- "vectorize/results/b6_text_tricks.csv"
pk <- c("stringi", "stringr")
set.seed(6)
V <- 3000
vocab <- stri_rand_strings(V, sample(3:10, V, TRUE), "[a-z]")
cap <- sample(V, 300); vocab[cap] <- stri_trans_totitle(vocab[cap])
nonascii <- c("café", "naïve", "straße", "ﬁnancial", "ﬂow", "İstanbul", "ΣAΣ", "Zürich", "œuvre", "déjà")
vocab[sample(V, length(nonascii))] <- nonascii
prob <- 1 / seq_len(V); prob <- prob / sum(prob)
mk_docs <- function(n, nw = 230) do.call(stri_join, c(lapply(seq_len(nw), \(j) sample(vocab, n, TRUE, prob)), sep = " "))
dict_lits <- vocab[sample(2500:3000, 20)]
mid <- vocab[sample(100:500, 20)]
rx <- stri_c("\\b", dict_lits, "(?:\\W+\\w+){0,3}?\\W+", mid, "\\b")
ns <- if (length(commandArgs(TRUE))) as.numeric(commandArgs(TRUE)) else c(1e4, 1e5)
for (n in ns) {
  if (!fits_or_skip(n * 1500 / 2^20, 6, sprintf('b6 docs n=%g', n))) next
  docs <- mk_docs(n); cat("n", n, "mean nchar", mean(nchar(docs)), "\n")
  # (1) fixed prefilter before regex, per dictionary entry
  full <- \() vapply(seq_along(rx), \(i) stri_detect_regex(docs, rx[i]), logical(n))
  pref <- \() vapply(seq_along(rx), \(i) { h <- stri_detect_fixed(docs, dict_lits[i]); h[h] <- stri_detect_regex(docs[h], rx[i]); h }, logical(n))
  common <- vocab[1:20]; rxc <- stri_c("\\b", common, "(?:\\W+\\w+){0,3}?\\W+", mid, "\\b")
  prefc <- \() vapply(seq_along(rxc), \(i) { h <- stri_detect_fixed(docs, common[i]); h[h] <- stri_detect_regex(docs[h], rxc[i]); h }, logical(n))
  fullc <- \() vapply(seq_along(rxc), \(i) stri_detect_regex(docs, rxc[i]), logical(n))
  bm("G1 fixed prefilter, rare literal (hit ~1%)", n, f, pk, regex_only = full(), fixed_prefilter = pref(), max_iter = 5, min_time = 0)
  bm("G1 fixed prefilter, common literal (hit ~50-90%)", n, f, pk, regex_only = fullc(), fixed_prefilter = prefc(), max_iter = 5, min_time = 0)
  # (2) windowed regex anchored on rare token
  win_rx <- stri_c("^", "\\b", dict_lits, "(?:\\W+\\w+){0,3}?\\W+", mid, "\\b")
  wind <- \() vapply(seq_along(rx), \(i) {
    h <- stri_detect_fixed(docs, dict_lits[i]); out <- logical(n); idx <- which(h)
    if (length(idx)) {
      loc <- stri_locate_all_fixed(docs[idx], dict_lits[i], omit_no_match = TRUE)
      out[idx] <- vapply(seq_along(idx), \(j) { s <- loc[[j]][, 1]; any(stri_detect_regex(stri_sub(docs[idx[j]], s, length = 200), rx[i])) }, NA)
    }
    out }, logical(n))
  bm("G2 windowed regex anchored on rare token", n, f, pk, full_regex = full(), windowed = wind(),
     notes = "window = [start-1, start+199] chars around each literal hit, then regex; exact only if match span < window", max_iter = 3, min_time = 0)
  # (4) lowercase once vs case_insensitive per term
  terms <- c(tolower(vocab[sample(V, 80)]), "café", "straße", "µ", "zürich", "σaσ", "ﬁnancial", "istanbul", "œuvre", "déjà", "naïve")
  ci <- \() vapply(terms, \(t) stri_detect_fixed(docs, t, case_insensitive = TRUE), logical(n))
  low <- \() { l <- stri_trans_tolower(docs); vapply(terms, \(t) stri_detect_fixed(l, t), logical(n)) }
  lowb <- \() { l <- tolower(docs); vapply(terms, \(t) stri_detect_fixed(l, t), logical(n)) }
  rxci <- \() vapply(terms, \(t) stri_detect_regex(docs, stri_escape_unicode(t) |> stri_unescape_unicode(), case_insensitive = TRUE), logical(n))
  ref <- ci(); a <- low(); b <- lowb(); r <- rxci()
  mm <- \(x) sum(x != ref)
  cat("G4 mismatch cells (doc x term) vs fixed ci:", "stri_tolower", mm(a), "base tolower", mm(b), "regex ci", mm(r), "of", length(ref), "\n")
  asc <- stri_enc_isascii(docs); cat("ASCII-only docs:", sum(asc), "mismatch there (stri_tolower):", sum(a[asc, ] != ref[asc, ]), "\n")
  mismatch_terms <- terms[colSums(a != ref) > 0]; cat("terms with mismatch:", paste(mismatch_terms, collapse = ","), "\n")
  bm("G4 lowercase once vs case_insensitive per term", n, f, pk, fixed_case_insensitive = ci(), lowercase_once = low(), lowercase_once_base_tolower = lowb(), regex_case_insensitive = rxci(),
     notes = sprintf("mismatch cells vs fixed ci: stri_tolower %d, base tolower %d, regex ci %d, of %d; ASCII-only docs %d of %d", mm(a), mm(b), mm(r), length(ref), sum(asc), n), max_iter = 3, min_time = 0)
}
