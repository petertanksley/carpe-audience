# carpe_numbers.R — numbers by construction for Carpe Audience decks (Keyes 2011, pp. 33-41, 64-67, 79-80)
#
# A number on a slide or in the speaker notes should BE its source value, not a retyping of it.
#   1. A talk's facts.R pulls every number from the saved results with carpe_pull(), which records
#      where it came from and refuses values that fail the data floors (optional; set them for your data).
#   2. The deck renders them with carpe_number() in inline R:  `r n(f$suicide_m, "ratio_words")`
#      and every rendering is written to a ledger (<deck>_numbers.csv) by carpe_ledger_write().
#   3. check_numbers.R treats ledger numbers as traced by construction and only has to trace
#      the few typed by hand.
#
#   source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "carpe_numbers.R"))
#
# Styles for carpe_number() (Keyes's on-screen units):
#   "int"          104223       -> "104,223"
#   "dec1"         60.049       -> "60.0"
#   "pct"          0.143        -> "14%"      (a share 0-1; use scale = 1 for values already in %)
#   "one_in"       0.143        -> "1 in 7"   (friendly: rounds to 1 in 7/12/50... only within 10%)
#   "ratio"        165.9        -> "166"      (PMR/SMR on the x100 scale)
#   "ratio_words"  165.9        -> "two-thirds higher"; 218 -> "more than double"; 24 -> "about a quarter of"
#   "times"        2.18         -> "2.2 times"
#   "ordinal"      48           -> "48th"     (rankings, p. 64)
#   "big_count"    3.0e7        -> "30 Million" (p. 36)
#   "diff"         15.84        -> "16"        (a difference; pass the difference)
# Every style keeps the value it was built from; the ledger records value, text and source.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# Created once: re-sourcing this file (facts.R and carpe_generators.R both do) must not wipe it.
if (!exists(".carpe_ledger", inherits = FALSE)) {
  .carpe_ledger <- new.env(parent = emptyenv())
  .carpe_ledger$rows <- list()
}

# A fact: a number with provenance. kind = "estimate" (rates, ratios, proportions; floor 20) or
# "count" (tallies; floor 10). count = the observed deaths behind it, when known.
# label: what the number IS, in plain language ("Suicide, male officers (PMR)"); the handout uses it.
carpe_fact <- function(value, source, where = "", count = NA_real_, kind = c("estimate", "count"),
                       floors = c(estimate = 20, count = 10), label = NA_character_) {
  kind <- match.arg(kind)
  if (!is.na(count) && count < floors[["count"]])
    stop(sprintf("%s %s: underlying count %s < %d (disclosure floor). Do not publish.", source, where, count, floors[["count"]]))
  if (kind == "estimate" && !is.na(count) && count < floors[["estimate"]])
    stop(sprintf("%s %s: estimate rests on %s < %d deaths (reliability floor).", source, where, count, floors[["estimate"]]))
  structure(value, class = "carpe_fact", source = source, where = where, count = count, kind = kind, label = label)
}
print.carpe_fact <- function(x, ...) {
  cat(sprintf("%s  [%s %s; %s%s]\n", format(unclass(x)), attr(x, "source"), attr(x, "where"),
              attr(x, "kind"), if (is.na(attr(x, "count"))) "" else paste0(", n = ", attr(x, "count"))))
  invisible(x)
}

# Pull ONE value from a results file. `...` are dplyr filter conditions that must leave exactly
# one row. count_col names the observed-count column for the floor check (NA to skip).
carpe_pull <- function(file, column, ..., count_col = c("obs", "n"), kind = "estimate", floors = c(estimate = 20, count = 10),
                       label = NA_character_) {
  d <- if (grepl("\\.rds$", file, ignore.case = TRUE)) readRDS(file) else utils::read.csv(file)
  d <- dplyr::filter(as.data.frame(d), ...)
  if (nrow(d) != 1) stop(sprintf("carpe_pull(%s, %s): filter left %d rows, need exactly 1", basename(file), column, nrow(d)))
  cc <- intersect(count_col, names(d))
  cnt <- if (length(cc)) as.numeric(d[[cc[1]]]) else NA_real_
  # Record the filter with its VALUES (sex == "male"), not the caller's variable names.
  conds <- paste(vapply(rlang::enquos(...), function(q) {
    e <- rlang::quo_get_expr(q)
    if (is.call(e) && length(e) == 3 && as.character(e[[1]]) %in% c("==", "%in%"))
      paste(deparse(e[[2]]), as.character(e[[1]]), deparse(rlang::eval_tidy(e[[3]], env = rlang::quo_get_env(q))))
    else rlang::as_label(q)
  }, ""), collapse = ", ")
  carpe_fact(d[[column]], source = basename(file), where = sprintf("%s [%s]", column, conds),
             count = cnt, kind = kind, floors = floors, label = label)
}

# Arithmetic on facts keeps provenance (e.g. a difference of two means, a sum of counts).
carpe_derive <- function(value, from, how, label = NA_character_) {
  src <- paste(unique(vapply(from, function(x) attr(x, "source") %||% "?", "")), collapse = " + ")
  cnt <- suppressWarnings(min(vapply(from, function(x) attr(x, "count") %||% NA_real_, 0), na.rm = TRUE))
  structure(value, class = "carpe_fact", source = src, where = how,
            count = if (is.finite(cnt)) cnt else NA_real_, kind = attr(from[[1]], "kind") %||% "estimate", label = label)
}

.frac_words <- c(`0.1` = "a tenth", `0.2` = "a fifth", `0.25` = "a quarter", `0.333` = "a third",
                 `0.4` = "two-fifths", `0.5` = "half", `0.6` = "three-fifths", `0.667` = "two-thirds",
                 `0.75` = "three-quarters", `0.8` = "four-fifths")
.nearest_frac <- function(r) { v <- as.numeric(names(.frac_words)); i <- which.min(abs(v - r)); list(v = v[i], w = .frac_words[[i]]) }
.friendly_k <- c(2:10, 12, 15, 20, 25, 30, 40, 50, 75, 100, 200, 250, 500, 1000, 1e4, 1e5, 1e6)

carpe_number <- function(x, style = c("int", "dec1", "pct", "one_in", "ratio", "ratio_words", "times",
                                      "ordinal", "big_count", "diff"),
                         scale = NULL, friendly = TRUE, name = NULL) {
  style <- match.arg(style)
  v <- as.numeric(unclass(x))
  txt <- switch(style,
    int  = formatC(round(v), format = "d", big.mark = ","),
    dec1 = formatC(v, format = "f", digits = 1),
    diff = formatC(round(v), format = "d", big.mark = ","),
    ratio = formatC(round(v), format = "d"),
    pct  = { s <- scale %||% (if (abs(v) <= 1) 100 else 1); paste0(round(v * s), "%") },
    times = paste(formatC(v, format = "f", digits = 1), "times"),
    ordinal = { k <- round(v); suf <- if (k %% 100 %in% 11:13) "th" else c("th", "st", "nd", "rd", rep("th", 6))[k %% 10 + 1]; paste0(k, suf) },
    big_count = if (v >= 1e9) paste(format(round(v / 1e9, 1), drop0trailing = TRUE), "Billion")
                else if (v >= 1e6) paste(format(round(v / 1e6, 1), drop0trailing = TRUE), "Million")
                else formatC(round(v), format = "d", big.mark = ","),
    one_in = {
      share <- if (v > 1) v / 100 else v
      k <- 1 / share
      kf <- .friendly_k[which.min(abs(.friendly_k - k))]
      use_f <- friendly && abs(1 / kf - share) / share <= 0.10
      kk <- if (use_f) kf else round(k)
      paste0(if (abs(1 / kk - share) / share > 0.02) "about " else "", "1 in ", formatC(kk, format = "d", big.mark = ","))
    },
    ratio_words = {
      r <- v / 100                                   # PMR/SMR on the x100 scale
      if (abs(r - 1) < 0.10) "about the same"
      else if (r >= 3) paste("about", round(r), "times")
      else if (r >= 2.5) "nearly triple"
      else if (r >= 2) "more than double"
      else if (r > 1) { fr <- .nearest_frac(r - 1); paste0(if (abs(fr$v - (r - 1)) > 0.03) "about " else "", fr$w, " higher") }
      else { fr <- .nearest_frac(r); paste0(if (abs(fr$v - r) > 0.03) "about " else "", fr$w, " of") }
    }
  )
  .carpe_ledger$rows[[length(.carpe_ledger$rows) + 1]] <- data.frame(
    name = name %||% NA_character_, label = attr(x, "label") %||% NA_character_, text = txt, value = v, style = style,
    source = attr(x, "source") %||% NA_character_, where = attr(x, "where") %||% NA_character_,
    count = attr(x, "count") %||% NA_real_, stringsAsFactors = FALSE)
  if (!inherits(x, "carpe_fact")) warning("carpe_number(", txt, "): value has no provenance; build it with carpe_pull()")
  txt
}
n <- carpe_number   # short form for inline R:  `r n(f$x, "pct")`

# Write the ledger next to the deck at the end of the render (last chunk of the .qmd).
carpe_ledger_write <- function(path = NULL) {
  path <- path %||% sub("\\.[A-Za-z]+$", "_numbers.csv", knitr::current_input(dir = TRUE) %||% "deck.qmd")
  rows <- do.call(rbind, .carpe_ledger$rows)
  if (is.null(rows)) rows <- data.frame(name = character(), text = character(), value = numeric())
  utils::write.csv(unique(rows), path, row.names = FALSE)
  invisible(path)
}
