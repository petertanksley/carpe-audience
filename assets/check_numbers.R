#!/usr/bin/env Rscript
# check_numbers.R — trace every number in a rendered Carpe deck to a declared source.
#
#   Rscript check_numbers.R talks/my_talk/my_talk.html [--from N] [--to N] [--out numbers.md]
#
# Sources are declared in the sibling .qmd's YAML, relative to the .qmd:
#   carpe:
#     sources:
#       - file: ../../analysis/output/results/pmr_mor_overall.rds   # data frame: ONLY the rows and
#         filter: occ_pso_groups == "police"                       #   columns named here count
#         columns: [pmr_scaled_100, pmr_scaled_100_lcl, pmr_scaled_100_ucl]
#       - ../../docs/IACP_police_results_summary.md                  # text: every number written in it
#     floors: { estimate: 20, count: 10, count-col: [obs, n] }      # optional (restricted-data projects)
#     constants: [64, 100]                                          # definitions, not results
#
# Always restrict data-frame sources with filter/columns. Unrestricted, small integers match some
# cell somewhere (a count, an expected value, another group) and the trace means nothing.
#
# For each number on screen AND in the speaker notes it reports where it traces, or flags it.
# A number traces when some source value rounds to it at the number's own precision, directly,
# x100 (proportion -> percent / ratio -> scaled), or as "1 in K" (a share near 1/K). Years,
# runtimes and slide-mechanics numbers are skipped. When a match comes from a data-frame row with
# a count column, the count is checked against the floors.
#
# The point (numbers in the talk must match the tables they came from): every figure a speaker
# says or shows has a source a reviewer can find.

suppressPackageStartupMessages({ library(xml2); library(stringr); library(purrr); library(dplyr); library(yaml) })
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: Rscript check_numbers.R deck.html [--from N] [--to N] [--out numbers.md]")
html_path <- args[1]
opt <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i)) default else args[i + 1] }
from <- as.integer(opt("--from", "1")); to <- as.integer(opt("--to", NA)); out <- opt("--out")

qmd <- sub("\\.html$", ".qmd", html_path)
y <- str_match(paste(readLines(qmd, warn = FALSE), collapse = "\n"), "(?s)^---\\n(.*?)\\n---")[, 2]
carpe <- yaml.load(y)$carpe
srcs <- carpe$sources %||% character()
if (!length(srcs) && !file.exists(sub("\\.html$", "_numbers.csv", html_path)))
  stop("No carpe: sources: and no numbers ledger for ", qmd, "; nothing to trace against")
floors <- carpe$floors
count_cols <- unlist(floors$`count-col`) %||% c("obs", "n")

# ---- source values -----------------------------------------------------------
num_re <- "(?<![\\w.])-?\\d{1,3}(?:,\\d{3})+(?:\\.\\d+)?|(?<![\\w.])-?\\d+(?:\\.\\d+)?"

src_vals <- if (!length(srcs)) tibble(value = numeric(), source = character(), where = character(), count = numeric()) else map_dfr(srcs, function(s) {
  spec <- if (is.list(s)) s else list(file = s)
  p <- normalizePath(file.path(dirname(qmd), spec$file), mustWork = FALSE)
  if (!file.exists(p)) { warning("source not found: ", spec$file); return(NULL) }
  if (grepl("\\.(rds|csv)$", p, ignore.case = TRUE)) {
    d <- if (grepl("\\.rds$", p, ignore.case = TRUE)) readRDS(p) else utils::read.csv(p)
    d <- as.data.frame(d)
    if (!is.null(spec$filter)) d <- dplyr::filter(d, !!rlang::parse_expr(spec$filter))
    cc <- intersect(count_cols, names(d)); cc <- if (length(cc)) cc[1] else NA_character_
    nums <- unlist(spec$columns) %||% setdiff(names(d)[vapply(d, is.numeric, logical(1))], cc)
    if (is.null(spec$columns)) warning("source ", basename(p), " has no columns: restriction; matches will be loose")
    map_dfr(nums, function(col) tibble(
      value = d[[col]], source = basename(p), where = paste0(col, "[", seq_len(nrow(d)), "]"),
      count = if (is.na(cc)) NA_real_ else as.numeric(d[[cc]])
    ))
  } else {
    txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
    v <- str_extract_all(txt, num_re)[[1]]
    tibble(value = as.numeric(gsub(",", "", v)), source = basename(p), where = "text", count = NA_real_)
  }
})
src_vals <- filter(src_vals, is.finite(value))

# ---- deck numbers ------------------------------------------------------------
doc <- read_html(html_path, encoding = "UTF-8")
leaf <- xml_find_all(doc, "//div[contains(@class,'slides')]//section[not(.//section)]")
if (is.na(to)) to <- length(leaf)

clean <- function(x) {
  x |>
    str_remove_all(regex("(Type|Runtime):[^\\n·|]*", ignore_case = TRUE)) |>
    str_remove_all("\\(\\d{2,3}%? ?CI[^)]*\\)") |>            # CI text is checked as numbers below anyway
    str_replace_all("[–—]", " ")
}

deck <- map_dfr(seq(from, to), function(i) {
  s <- leaf[[i]]
  nn <- xml_find_first(s, ".//aside[contains(@class,'notes')]")
  if (!inherits(nn, "xml_missing")) xml_remove(xml_find_all(nn, ".//style|.//script"))
  notes <- if (inherits(nn, "xml_missing")) "" else xml_text(nn)
  vis <- read_html(as.character(s), encoding = "UTF-8"); xml_remove(xml_find_all(vis, ".//aside"))
  screen <- xml_text(vis)
  grab <- function(txt, where) {
    txt <- clean(txt)
    one_in <- str_match_all(txt, regex("\\b(?:1|one) in (\\d+|two|three|four|five|six|seven|eight|nine|ten|twelve|fifty)\\b", ignore_case = TRUE))[[1]][, 2]
    words <- c(two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, ten = 10, twelve = 12, fifty = 50)
    k <- suppressWarnings(ifelse(is.na(as.numeric(one_in)), words[tolower(one_in)], as.numeric(one_in)))
    raw <- str_extract_all(str_remove_all(txt, regex("\\b(?:1|one) in \\w+", ignore_case = TRUE)), num_re)[[1]]
    pct <- str_detect(txt, fixed(paste0(raw, "%")))
    bind_rows(
      tibble(slide = i, where = where, token = raw, value = as.numeric(gsub(",", "", raw)), kind = ifelse(pct, "percent", "number")),
      tibble(slide = i, where = where, token = paste("1 in", one_in), value = 1 / k, kind = rep("one_in", length(k)))
    )
  }
  bind_rows(grab(screen, "screen"), grab(notes, "notes"))
})

# skip years and pure slide mechanics
deck <- deck |> filter(!(kind == "number" & value >= 1900 & value <= 2100 & !str_detect(token, "[.,]")))

decimals <- function(tok) ifelse(str_detect(tok, "\\."), nchar(str_extract(tok, "(?<=\\.)\\d+")), 0L)

trace_one <- function(tok, val, kind) {
  d <- decimals(tok)
  sv <- src_vals$value
  hit <- switch(kind,
    one_in  = which(sv > 0 & sv < 1 & round(1 / sv) == round(1 / val) |
                    sv > 1 & sv < 100 & round(100 / sv) == round(1 / val)),   # share or percent
    percent = which(round(sv * 100, d) == val | round(sv, d) == val),
    number  = {
      tz <- if (d == 0 && abs(val) >= 1000) nchar(str_extract(gsub(",", "", tok), "0+$") %||% "") else 0L
      tz <- ifelse(is.na(tz), 0L, tz)
      if (tz >= 2) which(round(sv, -tz) == val)                    # "about 94,000", "10,000"
      else which(round(sv, d) == val | round(sv * 100, d) == val)
    }
  )
  if (!length(hit)) return(tibble(traced = FALSE, src = NA_character_, count = NA_real_, n_alt = 0L))
  # prefer data-frame matches (they carry counts), then text
  h <- hit[order(src_vals$where[hit] == "text")][1]
  tibble(traced = TRUE,
         src = sprintf("%s:%s (= %s)", src_vals$source[h], src_vals$where[h], signif(src_vals$value[h], 6)),
         count = src_vals$count[h], n_alt = length(unique(hit)) - 1L)
}

# Numbers rendered by carpe_number() are traced by construction: the ledger written at render time
# (<deck>_numbers.csv, carpe_ledger_write()) holds each rendered text with its value and source.
ledger_path <- sub("\\.html$", "_numbers.csv", html_path)
ledger <- if (file.exists(ledger_path)) utils::read.csv(ledger_path, stringsAsFactors = FALSE) else NULL
from_ledger <- function(tok, kind) {
  if (is.null(ledger)) return(NULL)
  key <- if (kind == "one_in") tok else gsub(",", "", tok)
  hit <- which(vapply(ledger$text, function(x) {
    if (kind == "one_in") grepl(key, x, fixed = TRUE)
    else key %in% gsub(",", "", str_extract_all(x, num_re)[[1]])
  }, logical(1)))
  if (!length(hit)) return(NULL)
  h <- hit[1]
  tibble(traced = TRUE, src = sprintf("by construction: %s %s (= %s)", ledger$source[h], ledger$where[h], signif(ledger$value[h], 6)),
         count = ledger$count[h], n_alt = 0L)
}

# Definitional constants (an age cutoff, a reference line of 100) are declared, not traced:
#   carpe: constants: [64, 100]
constants <- as.numeric(unlist(carpe$constants))
as_constant <- function(tok, val, kind) if (kind == "number" && val %in% constants)
  tibble(traced = TRUE, src = "declared constant (carpe: constants)", count = NA_real_, n_alt = 0L) else NULL

res <- deck |>
  mutate(t = pmap(list(token, value, kind), function(tok, val, kind)
    as_constant(tok, val, kind) %||% from_ledger(tok, kind) %||% trace_one(tok, val, kind))) |>
  tidyr::unnest(t)

# floors on matched rows
if (!is.null(floors)) {
  est_floor <- floors$estimate %||% 20; cnt_floor <- floors$count %||% 10
  res <- res |> mutate(floor_flag = case_when(
    !is.na(count) & count < cnt_floor ~ sprintf("underlying count %d < %d (disclosure)", as.integer(count), cnt_floor),
    !is.na(count) & count < est_floor ~ sprintf("underlying count %d < %d (estimate floor)", as.integer(count), est_floor),
    TRUE ~ NA_character_))
} else res$floor_flag <- NA_character_

untraced <- res |> filter(!traced)
flagged  <- res |> filter(!is.na(floor_flag))

lines <- c(
  sprintf("# Number provenance: %s (slides %d-%d)", basename(html_path), from, to), "",
  sprintf("Sources: %s", paste(basename(vapply(srcs, function(s) if (is.list(s)) s$file else s, "")), collapse = ", ")),
  sprintf("Numbers checked: %d (screen %d, notes %d). Traced: %d (%d by construction). Untraced: %d. Floor flags: %d.",
          nrow(res), sum(res$where == "screen"), sum(res$where == "notes"), sum(res$traced),
          sum(startsWith(res$src %||% "", "by construction"), na.rm = TRUE), nrow(untraced), nrow(flagged)),
  "", "## Untraced (fix the number or add its source)",
  if (nrow(untraced)) sprintf("- slide %d, %s: **%s**", untraced$slide, untraced$where, untraced$token) else "- none",
  "", "## Floor flags",
  if (nrow(flagged)) sprintf("- slide %d, %s: %s -> %s", flagged$slide, flagged$where, flagged$token, flagged$floor_flag) else "- none",
  "", "## Traced",
  with(res[res$traced, ], sprintf("- slide %d, %s: %s <- %s%s", slide, where, token, src,
       ifelse(n_alt > 0, sprintf("  _(+%d other matches: check this is the intended one)_", n_alt), "")))
)
cat(lines, sep = "\n")
if (!is.null(out)) writeLines(lines, out)
quit(status = if (nrow(untraced) || nrow(flagged)) 1 else 0)
