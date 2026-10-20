# carpe_generators.R — Keyes's numeric slide sequences, generated from facts (Keyes 2011)
#
#   source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "carpe_generators.R"))
#
# Each generator returns slide markdown. Emit it from a chunk with  #| output: asis  and cat():
#
#   ```{r}
#   #| output: asis
#   cat(carpe_highlight_fact(topic = "Three causes", story = "The finding",
#         items = list(Suicide = f$suicide_m, Liver = f$liver_m, Poisoning = f$poison_m), style = "ratio"))
#   ```
#
# Numbers go through carpe_number(), so they land in the ledger and are traced by construction.
# Runtimes are marked "est" until rehearsed. Slides are duplicated per step, never fragments
# (p. 91). Notes carry a scaffold for the spoken story; replace the [bracketed] prompts.
#
#   carpe_series()          statistical series (p. 64): setup, then one number per slide, fast,
#                           slowing on the punchline. Ordinals for rankings, percentages, counts.
#   carpe_highlight_fact()  highlight the fact (p. 67): topic -> group unlit -> each item lit with
#                           its statistic -> group again. Statistic, human example, statistic again.
#   carpe_number_story()    derived-number build, after "One in a Million" (pp. 36-37): a chain of
#                           numbers (count -> derived count -> derived % -> complement -> reframe)
#                           at 2-7 s a slide, ending on a Call to Action.

source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "carpe_numbers.R"))

.carpe_slide <- function(classes = character(), body = "", notes = "", type = "Background",
                         story = "Story", runtime = 10, heading = "", bg = NULL, bg_pos = "50% 50%") {
  attrs <- paste0(".", classes, collapse = " ")
  if (!is.null(bg)) attrs <- paste0(attrs, sprintf(' background-image="%s" background-size="cover" background-position="%s"', bg, bg_pos))
  paste0(
    "## ", heading, if (nzchar(heading)) " " else "", "{", attrs, "}\n\n",
    body, "\n\n",
    "::: {.notes}\n", if (nzchar(notes)) paste0(notes, "\n") else "",
    sprintf("Type: %s · Story: %s · Runtime: %s s est\n", type, story, runtime),
    ":::\n\n"
  )
}
.items_line <- function(words, lit = NA) {
  spans <- vapply(seq_along(words), function(i) sprintf("[%s]{.%s}", words[i], if (!is.na(lit) && i == lit) "on" else "off"), "")
  paste0("::: {.items}\n", paste(spans, collapse = " "), "\n:::")
}

# items: named list of facts (names are the on-screen labels; keep each <= 3 words).
# style: one carpe_number() style, or a vector per item. punchline: index of the slow slide
# (default the last). images: optional vector of background images, one per item (p. 64 pairs
# each number with a reinforcing image).
carpe_series <- function(items, style = "int", setup = NULL, punchline = length(items),
                         fast = 2, slow = 10, story = "Series", type = "Background", images = NULL) {
  style <- rep_len(style, length(items))
  out <- if (!is.null(setup)) .carpe_slide("medium", setup, "[Setup line: what the numbers are, in one sentence.]",
                                           "Set the Stage", story, 5) else ""
  for (i in seq_along(items)) {
    num <- carpe_number(items[[i]], style[i], name = names(items)[i])
    slow_i <- i == punchline
    notes <- if (slow_i) sprintf("SLOW DOWN. %s: %s. [beat] [Human example: one person, one place.] [beat] %s, %s.",
                                 names(items)[i], num, num, names(items)[i])
             else sprintf("%s: %s. Click straight through.", names(items)[i], num)
    out <- paste0(out, .carpe_slide("big", sprintf("%s [%s]{.label}", num, names(items)[i]), notes,
                                    type, story, if (slow_i) slow else fast,
                                    bg = if (!is.null(images)) images[i] else NULL))
  }
  out
}

carpe_highlight_fact <- function(items, style = "int", topic = NULL, story = "Facts",
                                 type = "Background", per_item = 20) {
  style <- rep_len(style, length(items))
  words <- names(items)
  out <- if (!is.null(topic)) .carpe_slide("medium", topic, "[Name the topic. Nothing else yet.]", "Set the Stage", story, 5) else ""
  out <- paste0(out, .carpe_slide("power", .items_line(words), "[The whole group, nothing lit. Name them once.]", type, story, 5))
  for (i in seq_along(items)) {
    num <- carpe_number(items[[i]], style[i], name = words[i])
    notes <- sprintf("%s: %s. [beat] [Human example: who this is, where, what happened.] [beat] Remember: %s, %s.",
                     words[i], num, words[i], num)
    out <- paste0(out, .carpe_slide("power", paste0(.items_line(words, i), "\n\n[", num, "]{.stat}"), notes, type, story, per_item))
  }
  paste0(out, .carpe_slide("power", .items_line(words), "[The group again: the pattern in one sentence.]", "Transition", story, 5))
}

# steps: list of lists, each list(fact = <carpe_fact>, style = "...", label = "<= 3 words",
# runtime = 3). The last step is the reframe; it is typed Call to Action unless cta = FALSE.
# A step may carry chart = "figures/x.png" instead of a number (the scale-building bar, p. 37).
carpe_number_story <- function(steps, story = "Number story", cta = TRUE) {
  out <- ""
  for (i in seq_along(steps)) {
    s <- steps[[i]]
    last <- i == length(steps)
    body <- if (!is.null(s$chart)) sprintf("![](%s)", s$chart)
            else if (!is.null(s$fact)) sprintf("%s [%s]{.label}", carpe_number(s$fact, s$style %||% "int", name = s$label), s$label %||% "")
            else s$text
    cls <- if (!is.null(s$chart)) "chart" else if (!is.null(s$fact)) "big" else "medium"
    out <- paste0(out, .carpe_slide(cls, body, s$say %||% "[Say the sentence this number belongs to.]",
                                    if (last && cta) "Call to Action" else "Background", story, s$runtime %||% 3))
  }
  out
}
