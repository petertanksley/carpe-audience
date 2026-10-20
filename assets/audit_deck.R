#!/usr/bin/env Rscript
# audit_deck.R — mechanical Carpe Audience audit of a rendered Quarto RevealJS deck (Keyes 2011).
#
#   Rscript audit_deck.R talks/my_talk/my_talk.html [--from N] [--to N] [--out report.md] [--cadence cadence.csv]
#
# Reads the RENDERED html (what the audience sees) plus the sibling .qmd's `carpe:` YAML.
# --from/--to audit a run of slides (1-based, presentation order), e.g. one panelist's segment.
# --cadence writes Keyes's cadence worksheet (Time / Story / Type / Slide, p. 41) as CSV.
#
# Notes tag line expected on every slide:
#   Type: <Call to Action|Background|Set the Stage|Break|Transition> · Story: <name> · Runtime: <N> s [est]
#
# Checks, with the book pages they come from:
#   words on screen <= 7, charts included via data-carpe-words (p. 44); quote/long slides need a
#   PAUSE cue (pp. 44, 100); no bullets (p. 63); no montage, one picture per slide (p. 75);
#   notes + tags (pp. 41, 90); notes don't echo the slide (pp. 21, 26); closing = call to action or
#   a callback quote (pp. 27, 39, 45); slot fit x1.10 (p. 93); rapid-fire = 3-5 slides in <= 10 s
#   (pp. 36, 45); holds > 30 s need spoken beats (pp. 35, 41, 43); a hook/transition near every
#   10-minute mark and stories of 2-5 min (pp. 29, 35, 41, 91); registration: no per-slide
#   centring, no AutoFit analogues, no fragments on text, one transition (pp. 47, 61, 91);
#   no ALL-CAPS emphasis (p. 47); image resolution (p. 75); est runtimes left unrehearsed (p. 93).
# The echo check fires only at >= 5 words on purpose: the statistic -> anecdote -> statistic
# pattern (p. 67) REQUIRES saying a number-only slide aloud. Do not tighten it.

suppressPackageStartupMessages({ library(xml2); library(stringr); library(purrr); library(dplyr); library(yaml) })
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: Rscript audit_deck.R deck.html [--from N] [--to N] [--out report.md] [--cadence cadence.csv]")
html_path <- args[1]
opt <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i)) default else args[i + 1] }
from <- as.integer(opt("--from", "1")); to <- as.integer(opt("--to", NA)); out <- opt("--out"); cad <- opt("--cadence")

MAX_WORDS <- 7
TYPES <- c("call to action", "background", "set the stage", "break", "transition")
BEAT  <- regex("\\[beat\\]|\\[pause\\]|\\[voice\\]|\\bPAUSE\\b|\\bsilent\\b|\\bsilence\\b")

doc  <- read_html(html_path, encoding = "UTF-8")
leaf <- xml_find_all(doc, "//div[contains(@class,'slides')]//section[not(.//section)]")

words <- function(x) { x <- str_squish(x); if (!nzchar(x)) 0L else length(str_split(x, "\\s+")[[1]]) }

img_width <- function(src) {   # data-URI or relative file; PNG and JPEG headers
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

slides <- map_dfr(seq_along(leaf), function(i) {
  s <- leaf[[i]]
  cls <- xml_attr(s, "class") %||% ""
  nn <- xml_find_first(s, ".//aside[contains(@class,'notes')]")
  if (!inherits(nn, "xml_missing")) xml_remove(xml_find_all(nn, ".//style|.//script"))
  notes <- if (inherits(nn, "xml_missing")) "" else xml_text(nn)
  vis <- read_html(as.character(s), encoding = "UTF-8")
  xml_remove(xml_find_all(vis, ".//aside"))
  xml_remove(xml_find_all(vis, ".//*[contains(@class,'credit') or contains(@class,'byline') or contains(@class,'carpe-link') or self::figcaption]"))
  screen <- str_squish(xml_text(vis))
  imgs <- xml_find_all(vis, ".//img")
  chart_words <- sum(suppressWarnings(as.integer(xml_attr(imgs, "data-carpe-words"))), na.rm = TRUE)
  srcs <- c(xml_attr(imgs, "src"), na.omit(xml_attr(s, "data-background-image")))
  widths <- map_int(srcs, img_width)
  rt <- str_match(notes, regex("Runtime:\\s*([0-9.]+)\\s*s(\\s*est)?", ignore_case = TRUE))
  ty <- str_match(notes, regex("Type:\\s*([A-Za-z ]+?)\\s*(?:[^A-Za-z ]|Story|Runtime|$)", ignore_case = TRUE))[, 2]
  st <- str_match(notes, regex("Story:\\s*([^·|\\n]+?)\\s*(?:·|\\||Runtime|$)", ignore_case = TRUE))[, 2]
  styles <- xml_attr(xml_find_all(vis, ".//*[@style]"), "style")
  tibble(
    n = i, class = cls, title_slide = str_detect(cls, "quarto-title-block"),
    title = str_trunc(str_squish(xml_text(xml_find_first(s, ".//h1|.//h2"))), 40),
    screen_text = screen, screen_words = words(screen) + chart_words, chart_words = chart_words,
    is_quote = str_detect(cls, "\\bquote\\b"), contact_sheet = str_detect(cls, "contact-sheet"),
    bullets = length(xml_find_all(vis, ".//ul/li | .//ol/li")),
    n_img = length(srcs),
    min_img_w = if (length(widths) && any(!is.na(widths))) min(widths, na.rm = TRUE) else NA_real_,
    has_notes = nzchar(str_squish(notes)),
    pause_cue = str_detect(notes, regex("pause|silent|silence", ignore_case = TRUE)),
    beats = str_count(notes, BEAT),
    runtime = suppressWarnings(as.numeric(rt[, 2])), est = !is.na(rt[, 3]),
    type = str_to_lower(str_squish(ty %||% NA_character_)), story = str_squish(st %||% NA_character_),
    echo = words(screen) >= 5 && str_detect(str_squish(str_to_lower(notes)), fixed(str_to_lower(screen))),
    centred = str_detect(cls, "\\bcenter\\b") & !str_detect(cls, "quarto-title-block|level1"),   # Quarto adds .center to # dividers itself; the theme re-anchors them
    autofit = str_detect(cls, "r-fit-text|smaller|scrollable") || any(str_detect(styles, "font-size")) ||
              length(xml_find_all(vis, ".//*[contains(@class,'r-fit-text')]")) > 0,
    fragments = length(xml_find_all(vis, ".//*[contains(concat(' ', @class, ' '), ' fragment ')]")),
    transition = xml_attr(s, "data-transition") %||% NA_character_,
    caps_emph = str_detect(screen, "\\b[A-Z]{3,}\\b") && str_detect(screen, "[a-z]"),
    bg_image = !is.na(xml_attr(s, "data-background-image"))
  )
})
if (is.na(to)) to <- nrow(slides)
slides <- slides |> filter(n >= from, n <= to)

qmd <- sub("\\.html$", ".qmd", html_path)
meta <- if (file.exists(qmd)) {
  y <- str_match(paste(readLines(qmd, warn = FALSE), collapse = "\n"), "(?s)^---\\n(.*?)\\n---")[, 2]
  tryCatch(yaml.load(y)$carpe, error = function(e) NULL)
}
cta <- meta$`call-to-action`; slot <- meta$`slot-minutes`

# ---- findings ---------------------------------------------------------------
f <- list(); add <- function(sev, item, msg) f[[length(f) + 1]] <<- tibble(sev = sev, item = item, msg = msg)
each <- function(d, sev, item, fmt, ...) for (r in seq_len(nrow(d)))
  add(sev, item, do.call(sprintf, c(list(fmt), lapply(c(...), function(v) d[[v]][r]))))

ts <- slides |> filter(title_slide)
for (r in seq_len(nrow(ts))) {
  if (ts$screen_words[r] > MAX_WORDS) add("minor", "6 hook", sprintf("title slide carries %d words; a hook is a short title over one image (p. 63)", ts$screen_words[r]))
  if (!ts$bg_image[r]) add("advice", "6 hook", "title slide has no image; Keyes opens on a hook image with a call-to-action title (pp. 63, 77)")
}
# Backup slides (class .backup, after the close) are detail on demand: reported, not scored.
n_backup <- sum(str_detect(slides$class, "\\bbackup\\b"))
body <- slides |> filter(!title_slide, !str_detect(class, "\\bbackup\\b"))
each(body |> filter(screen_words > MAX_WORDS, !pause_cue), "major", "3 words",
     "slide %d (%s): %d words on screen (%d inside a chart); cut, or add a PAUSE cue if it must stay (p. 44)",
     "n", "title", "screen_words", "chart_words")
each(body |> filter(is_quote, !pause_cue), "minor", "3 words", "slide %d: quote slide without a PAUSE cue (p. 100)", "n")
each(body |> filter(bullets > 0), "major", "4 bullets", "slide %d (%s): %d on-screen list items; rebuild as a Power List", "n", "title", "bullets")
each(body |> filter(n_img > 1, !contact_sheet), "major", "11 montage", "slide %d: %d pictures; one per slide, never a montage (p. 75)", "n", "n_img")
each(body |> filter(!has_notes), "major", "2 notes", "slide %d (%s): no speaker notes", "n", "title")
nr <- body |> filter(has_notes, is.na(runtime))
if (nrow(nr)) add("minor", "2 tags", sprintf("no 'Runtime: N s' on slides %s", paste(nr$n, collapse = ", ")))
nt <- body |> filter(has_notes, is.na(type) | !type %in% TYPES)
if (nrow(nt)) add("minor", "2 tags", sprintf("no valid 'Type:' on slides %s", paste(nt$n, collapse = ", ")))
ns <- body |> filter(has_notes, is.na(story))
if (nrow(ns)) add("minor", "2 tags", sprintf("no 'Story:' on slides %s (needed for the cadence checks)", paste(ns$n, collapse = ", ")))
each(body |> filter(echo), "major", "5 echo", "slide %d: notes repeat the on-screen text verbatim (pp. 21, 26)", "n")
each(body |> filter(!is.na(min_img_w), min_img_w < 1280), "major", "12 resolution", "slide %d: image %d px wide (< 1280: jaggies, p. 75)", "n", "min_img_w")
each(body |> filter(!is.na(min_img_w), min_img_w >= 1280, min_img_w < 1920), "advice", "12 resolution", "slide %d: image %d px wide (ideally >= 1920, p. 75)", "n", "min_img_w")
each(body |> filter(autofit), "major", "9 registration", "slide %d: AutoFit analogue (r-fit-text/smaller/scrollable/inline font-size) (pp. 47, 61)", "n")
each(body |> filter(fragments > 0), "major", "16 animation", "slide %d: %d fragments; never animate text or Power Lists (p. 91)", "n", "fragments")
each(body |> filter(!is.na(transition), transition != "fade"), "minor", "16 animation", "slide %d: per-slide transition '%s'; one fade throughout (p. 91)", "n", "transition")
each(body |> filter(centred), "minor", "9 registration", "slide %d: centred one slide at a time; anchor top-left so type registers (pp. 60-61, 91)", "n")
each(body |> filter(caps_emph), "minor", "9 caps", "slide %d: ALL-CAPS word for emphasis; emphasis comes from the voice (p. 47)", "n")

# holds over 30 s need spoken beats about every 30 s (pp. 35, 41, 43)
hold <- body |> filter(!is.na(runtime), runtime > 30) |> mutate(need = floor(runtime / 30) - 1) |> filter(beats < need)
each(hold, "advice", "7 pacing", "slide %d holds %.0f s with %d beat marker(s); add [beat]/[pause]/[voice] about every 30 s (p. 35)", "n", "runtime", "beats")

# rapid-fire: a run of 3-5 slides, each <= 3 s, together <= 10 s (pp. 36, 45)
rt <- body$runtime; total <- sum(rt, na.rm = TRUE)
quick <- !is.na(rt) & rt <= 3
runs <- rle(quick); ends <- cumsum(runs$lengths)
rapid <- any(map_lgl(which(runs$values & runs$lengths >= 3), function(k) {
  idx <- (ends[k] - runs$lengths[k] + 1):ends[k]; runs$lengths[k] <= 5 && sum(rt[idx]) <= 10
}))
if (!rapid) add("advice", "7 pacing", "no rapid-fire run (3-5 slides in <= 10 s, then a pause) (pp. 36, 45)")

# closing: last content slide is a Call to Action, or a callback quote with a CTA in the last 3 min
content <- body |> filter(has_notes, is.na(type) | type != "transition")
if (nrow(content)) {
  last <- slice_tail(content, n = 1)
  cum_end <- cumsum(replace(rt, is.na(rt), 0))
  late_cta <- any(body$type == "call to action" & cum_end >= total - 180, na.rm = TRUE)
  ok <- identical(last$type, "call to action") || (last$is_quote && late_cta)
  if (!ok) add("major", "1 CTA", sprintf("last content slide (%d) is typed '%s'; close on the call to action or a callback quote (pp. 27, 39, 45)", last$n, last$type %||% "none"))
}
if (is.null(cta)) add("minor", "1 CTA", "no carpe: call-to-action in the .qmd YAML (p. 39)")
if (!is.null(slot) && total > 0 && total * 1.10 > slot * 60)
  add("major", "8 slot", sprintf("planned %.1f min x 1.10 = %.1f > slot %s min (p. 93)", total / 60, total * 1.1 / 60, slot))
n_est <- sum(body$est, na.rm = TRUE)
if (n_est) add("advice", "20 rehearsal", sprintf("%d runtimes are still 'est'; time them aloud with a stopwatch and replace (pp. 41, 93)", n_est))

# 10-minute hooks and story lengths (pp. 29, 35, 41, 91)
start <- c(0, head(cumsum(replace(rt, is.na(rt), 0)), -1))
if (total >= 600) for (m in seq(600, total, by = 600)) {
  near <- body$type %in% c("transition", "break") & abs(start - m) <= 60
  if (!any(near)) add("minor", "7 pacing", sprintf("no Transition/Break slide within 60 s of the %d-minute mark; reset attention there (pp. 29, 91)", m / 60))
}
stories <- tibble(story = body$story, start = start, rt = replace(rt, is.na(rt), 0)) |>
  filter(!is.na(story)) |> mutate(run = cumsum(story != lag(story, default = first(story)))) |>
  group_by(run, story) |> summarise(start = min(start), dur = sum(rt), .groups = "drop")
for (r in seq_len(nrow(stories))) if (stories$dur[r] > 360)
  add("advice", "7 pacing", sprintf("story '%s' runs %.1f min; Keyes's stories run 2-5 min, a new one every 3-6 (p. 35)", stories$story[r], stories$dur[r] / 60))

findings <- bind_rows(f)
ded <- c(major = 5, minor = 2, advice = 0)
score <- max(0, 100 - sum(ded[findings$sev %||% character()], na.rm = TRUE))

if (!is.null(cad)) {
  utils::write.csv(tibble(Time = sprintf("%d:%02d", start %/% 60, round(start %% 60)), Story = body$story,
                          Type = body$type, Slide = ifelse(nzchar(body$title), body$title, str_trunc(body$screen_text, 30)),
                          Runtime_s = body$runtime, Est = body$est), cad, row.names = FALSE)
}

lines <- c(
  sprintf("# Carpe Audience audit: %s (slides %d-%d)", basename(html_path), from, to), "",
  sprintf("Score: %d/100 (advisory; talks never block a commit)", score),
  sprintf("Call to action: %s", cta %||% "(none in YAML)"),
  sprintf("Planned runtime: %.1f min (x1.10 = %.1f) against slot: %s min%s", total / 60, total * 1.1 / 60, slot %||% "?",
          if (n_est) sprintf(" (%d of %d runtimes are estimates)", n_est, sum(!is.na(rt))) else ""),
  if (n_backup) sprintf("Backup slides: %d (not scored; detail on demand)", n_backup) else NULL,
  if (nrow(stories)) paste("Stories:", paste(sprintf("%s %.1f min", stories$story, stories$dur / 60), collapse = " · ")) else NULL,
  "", "| # | Title | Class | Words | Imgs | Notes | Type | Story | Runtime |", "|---|---|---|---|---|---|---|---|---|",
  sprintf("| %d | %s | %s | %d | %d | %s | %s | %s | %s |", slides$n, slides$title, slides$class, slides$screen_words, slides$n_img,
          ifelse(slides$has_notes, "yes", "**no**"), ifelse(is.na(slides$type), "", slides$type), ifelse(is.na(slides$story), "", slides$story),
          ifelse(is.na(slides$runtime), "", paste0(slides$runtime, " s", ifelse(slides$est, " est", "")))),
  "", "## Findings",
  if (nrow(findings)) sprintf("- **%s** [%s] %s", findings$sev, findings$item, findings$msg) else "- none",
  "", "## Judgment items for the reviewer (not machine-checkable)",
  "- Opening is a hook (image + call-to-action title), not a title/author card; no biography (pp. 36, 63)",
  "- Each image carries emotional or metaphorical weight; absence needs presence; no clip art or handshakes; credited (pp. 45, 66, 69, 120)",
  "- Each chart makes one point, sayable in one sentence; would one number do instead? (p. 79)",
  "- Every number is a story: statistic, human example, statistic again (pp. 39, 67)",
  "- Handout is a separate document in Keyes's format; for updates, a prose report circulated in advance (pp. 103, 107-113)",
  "- Rehearsed aloud 3+ times with clicker and speaker view; recording reviewed (pp. 93, 95, 116)"
)
cat(lines, sep = "\n")
if (!is.null(out)) writeLines(lines, out)
