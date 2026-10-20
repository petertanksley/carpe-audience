#!/usr/bin/env Rscript
# carpe_handout.R — a handout in Keyes's format, built from the rendered deck (pp. 21-22, 103, 107-113)
#
#   Rscript carpe_handout.R talks/my_talk/my_talk.html [--from N] [--to N] [--out handout.md] [--docx] [--technical]
#
# Never slide printouts (p. 22). Keyes's handout is a separate document:
#   1. Cover: what the talk is, "you may not need to take notes", contact details (p. 108).
#   2. Notes page: headings are the slides' napkin words, grouped by story, with an Action Items
#      column (p. 109). Writing on paper aids retention (p. 107).
#   3. The numbers: every number shown or said, with its source (research addition, from the
#      numbers ledger; the detail Keyes moves off the screen and onto paper, p. 79).
#   4. Questions page (p. 110).  5. Resources: every resource cited (p. 111).
#   6. Evaluation (p. 112, optional: carpe: evaluation: true).
# For updates and briefings Keyes's handout is instead a prose REPORT circulated in advance
# (p. 103); write that by hand and cite its pages from the slides.
#
# Reads from the deck's YAML `carpe:` block: call-to-action, allies, speaker, contact,
# resources (list), evaluation. --docx renders with the house Word style (render-word skill).

suppressPackageStartupMessages({ library(xml2); library(stringr); library(purrr); library(dplyr); library(yaml) })
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

args <- commandArgs(trailingOnly = TRUE)
html_path <- args[1]
opt <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i)) default else args[i + 1] }
from <- as.integer(opt("--from", "1")); to <- as.integer(opt("--to", NA))
out  <- opt("--out", sub("\\.html$", "_handout.md", html_path)); docx <- "--docx" %in% args
technical <- "--technical" %in% args   # academic audiences: add the file-and-filter provenance column

qmd <- sub("\\.html$", ".qmd", html_path)
y <- yaml.load(str_match(paste(readLines(qmd, warn = FALSE), collapse = "\n"), "(?s)^---\\n(.*?)\\n---")[, 2])
cp <- y$carpe %||% list()
title <- y$title %||% "Talk"

doc  <- read_html(html_path, encoding = "UTF-8")
leaf <- xml_find_all(doc, "//div[contains(@class,'slides')]//section[not(.//section)]")
if (is.na(to)) to <- length(leaf)
sl <- map_dfr(seq(from, to), function(i) {
  s <- leaf[[i]]; cls <- xml_attr(s, "class") %||% ""
  nn <- xml_find_first(s, ".//aside[contains(@class,'notes')]")
  notes <- if (inherits(nn, "xml_missing")) "" else xml_text(nn)
  vis <- read_html(as.character(s), encoding = "UTF-8")
  xml_remove(xml_find_all(vis, ".//aside|.//*[contains(@class,'credit') or contains(@class,'byline') or contains(@class,'carpe-link')]"))
  tibble(n = i, cls = cls, words = str_squish(xml_text(vis)),
         story = str_squish(str_match(notes, "Story:\\s*([^·|\\n]+?)\\s*(?:·|\\||Runtime|$)")[, 2] %||% NA_character_))
}) |> filter(!str_detect(cls, "backup|quarto-title-block"), nzchar(words))

stories <- sl |> filter(!is.na(story)) |>
  mutate(run = cumsum(story != lag(story, default = first(story)))) |>
  group_by(run, story) |> summarise(napkins = paste(unique(words), collapse = " · "), .groups = "drop")

ledger_path <- sub("\\.html$", "_numbers.csv", html_path)
ledger <- if (file.exists(ledger_path)) utils::read.csv(ledger_path, stringsAsFactors = FALSE) else NULL

md <- c(
  sprintf("# %s", title), "",
  if (!is.null(cp$speaker)) cp$speaker else NULL, "",
  "This handout goes with the talk. You may not need to take notes: the numbers and sources are here, and there is room below for what you want to act on.", "",
  if (!is.null(cp$`call-to-action`)) c(sprintf("**What we are asking:** %s", cp$`call-to-action`), "") else NULL,
  if (!is.null(cp$allies)) c(sprintf("**Who can help:** %s", cp$allies), "") else NULL,
  if (!is.null(cp$contact)) c(sprintf("**Contact:** %s", cp$contact), "") else NULL,
  "## Notes", "",
  "| Topic | Notes | Action items |", "|---|---|---|",
  sprintf("| **%s**: %s | | |", stories$story, stories$napkins), "",
  if (!is.null(ledger) && nrow(ledger)) {
    lg <- unique(ledger[, intersect(c("label", "text", "value", "source", "where"), names(ledger))])
    what <- if ("label" %in% names(lg)) ifelse(is.na(lg$label) | !nzchar(lg$label), lg$source, lg$label) else lg$source
    exact <- ifelse(lg$value == round(lg$value), formatC(lg$value, format = "d", big.mark = ","), formatC(lg$value, format = "f", digits = 2))
    c("## The numbers in this talk", "",
      "Every number shown or said, what it is, and its exact value.", "",
      if (technical) c("| As said | What it is | Exact value | Source |", "|---|---|---|---|",
                       sprintf("| %s | %s | %s | %s |", lg$text, what, exact, str_replace_all(paste(lg$source, lg$where), "\\|", "/")))
      else c("| As said | What it is | Exact value |", "|---|---|---|", sprintf("| %s | %s | %s |", lg$text, what, exact)), "")
  } else NULL,
  "## Questions", "",
  rep("Topic: ______________________________________________", 4), "",
  "## Resources", "",
  if (length(cp$resources)) paste0("- ", unlist(cp$resources)) else "- [List every resource cited in the talk: carpe: resources: in the deck YAML.]", "",
  if (isTRUE(cp$evaluation)) c("## Evaluation", "",
    "My role: [ ] Chief/command  [ ] Supervisor  [ ] Officer  [ ] Wellness/peer support  [ ] Other", "",
    "| | 1 | 2 | 3 | 4 |", "|---|---|---|---|---|",
    "| This was useful to my agency | | | | |", "| I know what to do next | | | | |", "",
    "One thing I will take back: ______________________________", "",
    "Contact me about this work (optional): ______________________________", "") else NULL
)
writeLines(md, out)
message("handout: ", out)

if (docx) {
  rw <- path.expand("~/.claude/skills/render-word")
  pandoc <- Sys.which("pandoc"); if (!nzchar(pandoc)) pandoc <- Sys.glob("/Applications/quarto/bin/tools/*/pandoc")[1]
  dx <- sub("\\.md$", ".docx", out)
  # house Word style if the render-word skill is installed; plain pandoc defaults otherwise
  style <- if (file.exists(file.path(rw, "apa-reference.docx"))) {
    c(paste0("--reference-doc=", shQuote(file.path(rw, "apa-reference.docx"))),
      paste0("--lua-filter=", shQuote(file.path(rw, "strip-hr.lua"))),
      paste0("--lua-filter=", shQuote(file.path(rw, "strip-internal-notes.lua"))))
  } else {
    message("handout: render-word not found, using pandoc's default Word style")
    character(0)
  }
  st <- system2(pandoc, c(shQuote(out), "-o", shQuote(dx), "--standalone", style))
  if (st == 0) message("handout: ", dx) else warning("pandoc failed on ", out)
}
