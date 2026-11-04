#!/usr/bin/env Rscript
# carpe_scrolly.R — turn a rendered Carpe Audience deck into a closeread scrollytelling page (Keyes 2011).
#
#   Rscript carpe_scrolly.R talks/my_talk/my_talk.html [--out my_talk_scrolly.qmd] [--layout overlay-right]
#                           [--from N] [--to N] [--css extra.css] [--title-slide keep|skip]
#
# The slide is the headline and the speaker is the story (p. 19). Closeread keeps that split: each
# slide becomes a STICKY (a 16:9 frame, class .carpe-slide, styled by carpe-scrolly.scss exactly as
# carpe.scss styles the deck) and each slide's notes become the NARRATIVE that triggers it. One
# closeread section per Story (the notes tag line), with the story name as a chapter heading.
# Backup slides (.backup) are not stickies: they go after the last section as ordinary page content.
#
# Reads the RENDERED html (what the audience saw), so every number arrives already computed and is
# unchanged by construction. The notes go in VERBATIM minus the tag line and beat markers: they were
# written to be spoken, so every block is flagged for a rewrite pass in <out>_rewrite.md.
# Writes: <out>.qmd, <out>_rewrite.md, scrolly_assets/ (images decoded from data URIs), and copies
# carpe-scrolly.scss next to the page if it is not there (a copy, never a symlink).
# Then: quarto add qmd-lab/closeread --no-prompt (once per talk directory) and quarto render <out>.qmd.

suppressPackageStartupMessages({ library(xml2); library(stringr); library(purrr); library(dplyr); library(yaml) })
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: Rscript carpe_scrolly.R deck.html [--out page.qmd] [--layout overlay-right] [--from N] [--to N] [--css extra.css] [--title-slide keep|skip]")
html_path <- args[1]
opt <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i)) default else args[i + 1] }
dir     <- dirname(html_path)
stem    <- sub("\\.html$", "", basename(html_path))
out     <- opt("--out", file.path(dir, paste0(stem, "_scrolly.qmd")))
layout  <- opt("--layout", "overlay-right")
from    <- as.integer(opt("--from", "1")); to <- as.integer(opt("--to", NA))
extra_css <- opt("--css"); title_mode <- opt("--title-slide", "keep")
asset_dir <- file.path(dirname(out), "scrolly_assets")

BEAT <- regex("\\[beat\\]|\\[pause\\]|\\[voice\\]|\\bPAUSE:?\\b", ignore_case = TRUE)
TAG  <- regex("\\s*Type:\\s*[A-Za-z ]+?\\s*(?:·|\\|)\\s*Story:.*?Runtime:\\s*[0-9.]+\\s*s(?:\\s*est)?\\.?", ignore_case = TRUE)
SPOKEN <- c("you can see", "as you see", "on this slide", "this slide", "next slide", "here we", "here is", "here's",
            "look at", "let me", "I'll", "I will", "we're going to", "we are going to", "I'm going to", "right now",
            "today", "this morning", "this afternoon", "tonight", "in the room", "show of hands", "thank you")

# ---- parse the deck -------------------------------------------------------------------------------------
doc  <- read_html(html_path, encoding = "UTF-8")
leaf <- xml_find_all(doc, "//div[contains(@class,'slides')]//section[not(.//section)]")
words <- function(x) { x <- str_squish(x); if (!nzchar(x)) 0L else length(str_split(x, "\\s+")[[1]]) }

qmd <- sub("\\.html$", ".qmd", html_path)
front <- if (file.exists(qmd)) {
  y <- str_match(paste(readLines(qmd, warn = FALSE, encoding = "UTF-8"), collapse = "\n"), "(?s)^---\\n(.*?)\\n---")[, 2]
  tryCatch(yaml.load(y), error = function(e) NULL)
}
deck_title <- front$title %||% stem
meta <- front$carpe

# Data URIs (deck rendered with embed-resources) become files; relative paths are kept (same directory).
dir.create(asset_dir, showWarnings = FALSE)
n_assets <- 0L
materialise <- function(src, slide, k) {
  if (is.na(src) || !startsWith(src, "data:")) return(src)
  mime <- str_match(src, "^data:([^;,]+)")[, 2]
  ext  <- c("image/png" = "png", "image/jpeg" = "jpg", "image/jpg" = "jpg", "image/svg+xml" = "svg", "image/gif" = "gif", "image/webp" = "webp")[mime]
  if (is.na(ext)) return(src)
  path <- file.path(asset_dir, sprintf("s%02d_%d.%s", slide, k, ext))
  writeBin(jsonlite::base64_dec(sub("^data:[^,]+,", "", src)), path)
  n_assets <<- n_assets + 1L
  file.path("scrolly_assets", basename(path))
}
css_url <- function(x) sprintf("url('%s')", str_replace_all(x, "'", "%27"))

slides <- map(seq_along(leaf), function(i) {
  s   <- leaf[[i]]
  cls <- str_split(xml_attr(s, "class") %||% "", "\\s+")[[1]]
  cls <- cls[nzchar(cls)]
  nn  <- xml_find_first(s, ".//aside[contains(@class,'notes')]")
  notes <- if (inherits(nn, "xml_missing")) character(0) else {
    xml_remove(xml_find_all(nn, ".//style|.//script"))
    ps <- xml_find_all(nn, ".//p"); if (length(ps)) map_chr(ps, ~ xml_text(.x)) else xml_text(nn)
  }
  all_notes <- paste(notes, collapse = "\n")
  ty <- str_match(all_notes, regex("Type:\\s*([A-Za-z ]+?)\\s*(?:[^A-Za-z ]|Story|Runtime|$)", ignore_case = TRUE))[, 2]
  st <- str_match(all_notes, regex("Story:\\s*([^·|\\n]+?)\\s*(?:·|\\||Runtime|$)", ignore_case = TRUE))[, 2]
  narrative <- notes |> str_replace_all(TAG, "") |> str_replace_all(BEAT, "") |> str_squish()
  narrative <- narrative[nzchar(narrative)]
  # the on-screen part: the section's children minus notes and comments, images made eager and local
  vis <- read_html(paste0("<div>", as.character(s), "</div>"), encoding = "UTF-8")
  sec <- xml_find_first(vis, ".//section")
  xml_remove(xml_find_all(sec, ".//aside|.//comment()"))
  for (h in xml_find_all(sec, ".//h1|.//h2|.//h3")) if (!nzchar(str_squish(xml_text(h))) && !length(xml_find_all(h, ".//img"))) xml_remove(h)
  imgs <- xml_find_all(sec, ".//img")
  for (k in seq_along(imgs)) {
    src <- xml_attr(imgs[[k]], "src") %||% xml_attr(imgs[[k]], "data-src")
    xml_set_attr(imgs[[k]], "src", materialise(src, i, k)); xml_attr(imgs[[k]], "data-src") <- NULL
  }
  inner <- paste(as.character(xml_children(sec)), collapse = "\n")
  bg <- xml_attr(s, "data-background-image")
  style <- if (!is.na(bg)) paste0(
    "background-image:", css_url(materialise(bg, i, 0L)), ";",
    if (!is.na(xml_attr(s, "data-background-size"))) paste0("background-size:", xml_attr(s, "data-background-size"), ";") else "",
    if (!is.na(xml_attr(s, "data-background-position"))) paste0("background-position:", xml_attr(s, "data-background-position"), ";") else "",
    if (!is.na(xml_attr(s, "data-background-repeat"))) paste0("background-repeat:", xml_attr(s, "data-background-repeat"), ";") else "") else ""
  screen <- str_squish(xml_text(sec))
  list(n = i, id = xml_attr(s, "id") %||% sprintf("s%02d", i), class = cls, inner = inner, style = style, has_bg = !is.na(bg),
       title = str_squish(xml_text(xml_find_first(s, ".//h1|.//h2")) %||% ""), screen = screen,
       narrative = narrative, type = str_to_lower(str_squish(ty %||% NA_character_)), story = str_squish(st %||% NA_character_),
       is_title = "quarto-title-block" %in% cls, is_backup = "backup" %in% cls, is_level1 = "level1" %in% cls)
})
if (is.na(to)) to <- length(slides)
slides <- slides[seq_along(slides) >= from & seq_along(slides) <= to]
if (title_mode == "skip") slides <- discard(slides, ~ .x$is_title)

main    <- discard(slides, ~ .x$is_backup)
backups <- keep(slides, ~ .x$is_backup && !.x$is_level1)
# a story carries forward over slides without a tag (title block, dividers)
story <- map_chr(main, "story"); for (i in seq_along(story)) if (is.na(story[i]) && i > 1) story[i] <- story[i - 1]
if (any(!is.na(story))) story[is.na(story)] <- story[!is.na(story)][1]   # leading untagged slides (title block) join the first story
story[is.na(story)] <- "Opening"

# ---- emit ------------------------------------------------------------------------------------------------
drop <- c("slide", "level1", "level2", "center", "title-slide", "present", "past", "future", "stack")
sticky <- function(sl) {
  cls <- setdiff(sl$class, drop); if (sl$has_bg) cls <- c(cls, "has-bg")
  id  <- sprintf("cr-s%02d", sl$n)
  attr <- paste0("{#", id, " .carpe-slide", if (length(cls)) paste0(" .", cls, collapse = "") else "",
                 if (nzchar(sl$style)) sprintf(' style="%s"', sl$style) else "", "}")
  c(paste0("::: ", attr), "```{=html}", sl$inner, "```", ":::", "")
}
markers <- function(txt) { f <- SPOKEN[str_detect(str_to_lower(txt), fixed(str_to_lower(SPOKEN)))]; if (length(f)) paste(f, collapse = ", ") else "" }
narrative <- function(sl) {
  id <- sprintf("cr-s%02d", sl$n); txt <- paste(sl$narrative, collapse = " ")
  body <- if (length(sl$narrative)) sl$narrative else "*[narrative to write]* <!-- TODO: this slide has no notes; write the sentence it belongs to, or merge it into the previous block -->"
  c(sprintf("<!-- rewrite: s%02d · %s · %d words%s -->", sl$n, sl$story %||% "", words(txt), if (nzchar(markers(txt))) paste0(" · spoken: ", markers(txt)) else ""),
    sprintf('::: {focus-on="%s"}', id), paste(body, collapse = "\n\n"), ":::", "")
}

yaml_head <- c(
  "---", sprintf("title: %s", yaml::as.yaml(deck_title) |> str_trim()),
  if (!is.null(meta)) c("carpe:", paste0("  ", str_split(str_trim(as.yaml(meta), "right"), "\n")[[1]])),
  "format:", "  closeread-html:", "    theme: [default, carpe-scrolly.scss]",
  sprintf("    css: [%s]", paste(c("carpe-fonts.css", extra_css), collapse = ", ")),
  "    embed-resources: true", "    remove-header-space: true", "    toc: false",
  "    cr-section:", sprintf("      layout: %s", layout), "---", "",
  "<!--", sprintf("  Scrolly built from %s by carpe_scrolly.R on %s. Each sticky is a slide; each narrative", basename(html_path), format(Sys.Date())),
  "  block is that slide's notes, verbatim. Rewrite every block for a reader (see the _rewrite.md list),",
  "  keep the stickies as they are, and press p in the browser for presentation mode.",
  "  One section per Story. Re-running the converter overwrites this file.", "-->", "")

body <- character(0); cur <- NULL
for (i in seq_along(main)) {
  if (!identical(story[i], cur)) {
    if (!is.null(cur)) body <- c(body, ":::", "")
    cur <- story[i]
    body <- c(body, sprintf("## %s", cur), "", "::: {.cr-section}", "")
  }
  body <- c(body, sticky(main[[i]]), narrative(main[[i]]))
}
if (!is.null(cur)) body <- c(body, ":::", "")
if (length(backups)) {
  body <- c(body, "::: {.carpe-backup}", "", "## Backup", "")
  for (b in backups) {
    inner <- str_replace(b$inner, "(?s)<h2[^>]*>.*?</h2>\\s*", "")
    body <- c(body, sprintf("### %s {#%s}", b$title, b$id), "", "```{=html}", inner, "```", "")
  }
  body <- c(body, ":::", "")
}
writeLines(c(yaml_head, body), out, useBytes = TRUE)

# ---- rewrite list, theme copy, report ---------------------------------------------------------------------
rw <- map_dfr(main, ~ tibble(slide = sprintf("s%02d", .x$n), story = .x$story %||% "", type = .x$type %||% "",
                              screen = str_trunc(.x$screen, 40), words = words(paste(.x$narrative, collapse = " ")),
                              spoken = markers(paste(.x$narrative, collapse = " "))))
rw_path <- sub("\\.qmd$", "_rewrite.md", out)
writeLines(c(sprintf("# Rewrite pass: %s", basename(out)), "",
             "The narrative is the notes verbatim, written to be spoken. Rewrite each block for a reader:",
             "drop stage directions and room talk, keep the statistic / human example / statistic rhythm",
             "(p. 67), and let the sticky carry the headline. Spoken-prose markers found are listed.", "",
             "| Slide | Story | Type | Screen | Words | Spoken markers |", "|---|---|---|---|---|---|",
             sprintf("| %s | %s | %s | %s | %d | %s |", rw$slide, rw$story, rw$type, rw$screen, rw$words, rw$spoken)), rw_path, useBytes = TRUE)

skill <- Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience")
for (f in c("carpe-scrolly.scss")) {
  dst <- file.path(dirname(out), f)
  if (!file.exists(dst)) { file.copy(file.path(path.expand(skill), "assets", f), dst); cat("copied", f, "\n") }
}
if (!dir.exists(file.path(dirname(out), "_extensions", "qmd-lab", "closeread")))
  cat("closeread is not installed here: run  (cd", shQuote(dirname(out)), "&& quarto add qmd-lab/closeread --no-prompt)\n")
cat(sprintf("scrolly: %d stickies in %d sections, %d backup slides, %d images written to scrolly_assets/, %d narrative blocks flagged\n  %s\n  %s\n",
            length(main), sum(story != c("", head(story, -1))), length(backups), n_assets, nrow(rw), out, rw_path))
