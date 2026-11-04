#!/usr/bin/env Rscript
# audit_scrolly.R — mechanical Carpe Audience check of a rendered closeread scrolly page.
#
#   Rscript audit_scrolly.R talks/my_talk/my_talk_scrolly.html [--out report.md]
#
# A sticky is a slide and keeps the slide rules: <= 7 words on screen, charts counted via
# data-carpe-words (p. 44); no bullets (p. 63); one picture (p. 75); image >= 1280 px wide; a quote
# may run longer (p. 100). The narrative is the story and may run long, but every sticky needs a
# trigger (a sticky nobody scrolls to never appears), every trigger needs a sticky, and the page
# must end on the call to action or a callback (pp. 27, 39, 45). Advisory, like audit_deck.R.

suppressPackageStartupMessages({ library(xml2); library(stringr); library(purrr); library(dplyr); library(yaml) })
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: Rscript audit_scrolly.R page.html [--out report.md]")
html_path <- args[1]
opt <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i)) default else args[i + 1] }
out <- opt("--out")
MAX_WORDS <- 7

doc <- read_html(html_path, encoding = "UTF-8")
words <- function(x) { x <- str_squish(x); if (!nzchar(x)) 0L else length(str_split(x, "\\s+")[[1]]) }
img_width <- function(src) {   # data-URI or relative file; PNG and JPEG headers (as audit_deck.R)
  raw <- tryCatch({
    if (startsWith(src, "data:")) jsonlite::base64_dec(sub("^data:[^,]+,", "", src))
    else readBin(file.path(dirname(html_path), src), "raw", 2e6)
  }, error = function(e) NULL)
  if (is.null(raw) || length(raw) < 30) return(NA_integer_)
  if (identical(raw[1:4], as.raw(c(0x89, 0x50, 0x4e, 0x47)))) return(sum(as.integer(raw[17:20]) * 256^(3:0)))
  if (identical(raw[1:2], as.raw(c(0xff, 0xd8)))) {
    i <- 3L
    while (i < length(raw) - 9) {
      if (raw[i] != as.raw(0xff)) { i <- i + 1L; next }
      m <- as.integer(raw[i + 1]); len <- as.integer(raw[i + 2]) * 256 + as.integer(raw[i + 3])
      if (m %in% c(0xc0:0xc3, 0xc5:0xc7, 0xc9:0xcb, 0xcd:0xcf)) return(as.integer(raw[i + 7]) * 256 + as.integer(raw[i + 8]))
      i <- i + 2L + len
    }
  }
  NA_integer_
}
bg_src <- function(style) { m <- str_match(style %||% "", "background-image:\\s*url\\(['\"]?([^'\")]+)")[, 2]; m }

sections <- xml_find_all(doc, "//div[contains(concat(' ',@class,' '),' cr-section ')]")
stickies <- xml_find_all(doc, "//div[contains(concat(' ',@class,' '),' sticky ') and starts-with(@id,'cr-')]")
triggers <- xml_find_all(doc, "//div[contains(concat(' ',@class,' '),' trigger ')][@data-focus-on]")
focus    <- xml_attr(triggers, "data-focus-on")

st <- map_dfr(seq_along(stickies), function(i) {
  s <- stickies[[i]]; cls <- xml_attr(s, "class") %||% ""
  vis <- read_html(as.character(s), encoding = "UTF-8")
  xml_remove(xml_find_all(vis, ".//*[contains(@class,'credit') or contains(@class,'byline') or contains(@class,'carpe-link') or self::figcaption]"))
  imgs <- xml_find_all(vis, ".//img")
  chart_words <- sum(suppressWarnings(as.integer(xml_attr(imgs, "data-carpe-words"))), na.rm = TRUE)
  srcs <- c(xml_attr(imgs, "src"), bg_src(xml_attr(s, "style"))); srcs <- srcs[!is.na(srcs)]
  widths <- map_int(srcs, img_width)
  screen <- str_squish(xml_text(vis))
  tibble(n = i, id = xml_attr(s, "id"), class = cls, screen = screen, screen_words = words(screen) + chart_words,
         is_quote = str_detect(cls, "\\bquote\\b"), is_blank = str_detect(cls, "\\bblank\\b"),
         bullets = length(xml_find_all(vis, ".//ul/li | .//ol/li")), n_img = length(srcs),
         min_img_w = if (length(widths) && any(!is.na(widths))) min(widths, na.rm = TRUE) else NA_real_,
         triggers = sum(focus == xml_attr(s, "id")))
})
narr <- map_dfr(seq_along(triggers), function(i) {
  t <- triggers[[i]]; txt <- str_squish(xml_text(t))
  tibble(n = i, focus = focus[i], words = words(txt), stub = str_detect(txt, fixed("[narrative to write]")))
})

qmd <- sub("\\.html$", ".qmd", html_path)
meta <- if (file.exists(qmd)) {
  y <- str_match(paste(readLines(qmd, warn = FALSE), collapse = "\n"), "(?s)^---\\n(.*?)\\n---")[, 2]
  tryCatch(yaml.load(y)$carpe, error = function(e) NULL)
}

f <- character(0)
add <- function(level, msg) f <<- c(f, sprintf("- **%s** %s", level, msg))
if (!length(sections)) add("major", "no .cr-section: this is not a closeread page")
orphans <- st |> filter(triggers == 0, !is_blank)
if (nrow(orphans)) add("major", sprintf("%d stickies have no trigger and never appear: %s", nrow(orphans), paste(orphans$id, collapse = ", ")))
dangling <- setdiff(focus, st$id)
if (length(dangling)) add("major", sprintf("%d triggers point at no sticky: %s", length(dangling), paste(unique(dangling), collapse = ", ")))
over <- st |> filter(!is_quote, screen_words > MAX_WORDS)
for (r in seq_len(nrow(over))) add("major", sprintf("%s: %d words on the sticky (> %d, p. 44): \"%s\"", over$id[r], over$screen_words[r], MAX_WORDS, str_trunc(over$screen[r], 60)))
bl <- st |> filter(bullets > 0)
for (r in seq_len(nrow(bl))) add("major", sprintf("%s: %d bullet items on a sticky (p. 63)", bl$id[r], bl$bullets[r]))
mont <- st |> filter(n_img > 1)
for (r in seq_len(nrow(mont))) add("minor", sprintf("%s: %d images on one sticky; one picture per frame (p. 75)", mont$id[r], mont$n_img[r]))
lowres <- st |> filter(!is.na(min_img_w), min_img_w < 1280)
for (r in seq_len(nrow(lowres))) add("major", sprintf("%s: image %d px wide (< 1280: jaggies, p. 75)", lowres$id[r], lowres$min_img_w[r]))
stubs <- narr |> filter(stub)
if (nrow(stubs)) add("major", sprintf("%d narrative blocks are still stubs: %s", nrow(stubs), paste(stubs$focus, collapse = ", ")))
short <- narr |> filter(!stub, words < 8)
if (nrow(short)) add("advice", sprintf("%d narrative blocks under 8 words (%s): a reader needs the sentence the slide belongs to", nrow(short), paste(short$focus, collapse = ", ")))
last <- st$screen[nrow(st)] %||% ""
if (str_detect(str_to_lower(last), "questions\\?|in summary|thank you|^summary$")) add("major", sprintf("last sticky is \"%s\": close on the call to action or a callback (pp. 27, 45)", last))
cta <- meta$`call-to-action` %||% ""
if (nzchar(cta)) {
  key <- str_to_lower(str_squish(str_sub(cta, 1, 40)))
  body_txt <- str_to_lower(str_squish(xml_text(xml_find_first(doc, "//main"))))
  if (!str_detect(body_txt, fixed(str_sub(key, 1, 25)))) add("advice", "the YAML call-to-action does not appear on the page; the close should say it (p. 39)")
}
if (any(str_detect(xml_attr(stickies, "class") %||% "", "carpe-slide")) == FALSE) add("advice", "stickies lack .carpe-slide: the Carpe frame styles will not apply")

report <- c(sprintf("# Carpe scrolly audit: %s", basename(html_path)), "",
            sprintf("%d sections · %d stickies · %d triggers · %d narrative words · %d stubs", length(sections), nrow(st), nrow(narr), sum(narr$words), sum(narr$stub)), "",
            "| # | Sticky | Class | Words | Imgs | Triggers | Screen |", "|---|---|---|---|---|---|---|",
            sprintf("| %d | %s | %s | %d | %d | %d | %s |", st$n, st$id, str_replace_all(st$class, "carpe-slide|sticky", "") |> str_squish(), st$screen_words, st$n_img, st$triggers, str_trunc(st$screen, 40)),
            "", "## Findings", if (length(f)) f else "- none", "",
            "## For the reviewer (not machine-checkable)",
            "- Each narrative block reads as prose for a reader, not a transcript: no room talk, no stage directions (rewrite list)",
            "- Statistic, human example, statistic again survives the rewrite (p. 67)",
            "- Each chapter (section) is one Story of 2-5 minutes' reading; a hook or turn near every third (pp. 29, 35)",
            "- Press p: the page works as a clicker deck in presentation mode")
if (!is.null(out)) writeLines(report, out) else cat(report, sep = "\n")
