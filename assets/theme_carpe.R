# theme_carpe.R — slide-scale ggplot2 helpers for Carpe Audience decks (Keyes 2011, ch. 15)
#
# One chart, one point. Black ground to match the deck, white type in the deck's font, every
# series grey except the one the speaker is talking about, direct labels instead of legends,
# exported at 1920x1080 so it stays sharp on any projector.
#
#   source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"),
#                    "assets", "theme_carpe.R"))
#   p <- ggplot(d, aes(x, y, colour = carpe_highlight(group, "Suicide"))) +
#     geom_point(size = 6) +
#     scale_colour_carpe() +
#     theme_carpe()
#   save_slide_fig(p, "talks/my_talk/figures/fig_suicide.png")
#
# Colour: Keyes picks chart colours "for drama" (p. 80). The ONE-accent-on-grey rule here is this
# skill's research adaptation of that, not Keyes's rule: the drama lives in sequencing and
# highlighting while the encodings stay honest. The accent is for chart MARKS only; on-screen type
# stays white/grey (pp. 60, 90).
#
# Sizes: the chart shares the deck's three sizes (p. 47). A 1920x1080 figure shown on a 720-px
# slide at max-height 600 is scaled by about 0.556, so carpe_pt() converts a deck size into the
# figure's points. Tick labels and axis text = small; direct value labels = medium.
#
# Words: save_slide_fig() writes a sidecar <file>.json with every word the chart puts on screen
# (titles, axis titles, discrete tick labels, strips, text labels). Insert the figure with
#   `r carpe_fig("figures/x.png")`
# so the image carries data-carpe-words and the audit counts chart text against the seven-word
# rule (p. 44). Over seven words needs a PAUSE cue in the notes.
#
# "Motion" (Godin, via Keyes p. 79-80): two or more slides on the SAME axes, where only the data
# changes: where it was, then where it is (or is going). See carpe_motion() in carpe_numbers.R.

carpe_pal <- list(
  ink    = "#ffffff",   # type, the highlighted reference line
  accent = "#f2b84b",   # the ONE highlighted series (chart marks only, never on-screen type)
  dim    = "#6b6b6b",   # everything the speaker is not talking about
  grid   = "#2a2a2a",
  bg     = "#000000"
)

# Register the deck's font for ggplot so charts and slides share one typeface (R10).
carpe_register_font <- function(font_dir = file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"),
                                                     "assets", "fonts")) {
  font_dir <- path.expand(font_dir)
  f <- function(w) file.path(font_dir, paste0("BarlowCondensed-", w, ".ttf"))
  if (!all(file.exists(f(c("SemiBold", "ExtraBold"))))) {
    warning("Barlow Condensed not found in ", font_dir, "; falling back to sans.")
    return(invisible("sans"))
  }
  systemfonts::register_font(
    name  = "Barlow Condensed Carpe",
    plain = f("SemiBold"), bold = f("ExtraBold"),
    italic = f("SemiBold"), bolditalic = f("ExtraBold")
  )
  invisible("Barlow Condensed Carpe")
}

# Deck size (px on a 1280x720 slide) -> points in a figure saved at `dpi` and shown at `shown_h` px
# of a `fig_h`-px-high image. small = 22 px, medium = 76 px, big = 240 px (carpe.scss tokens).
carpe_pt <- function(size = c("small", "medium", "big"), dpi = 144, fig_h = 1080, shown_h = 600) {
  px <- c(small = 22, medium = 76, big = 240)[match.arg(size)]
  unname(px / (shown_h / fig_h) * 72 / dpi)
}
# geom_text() sizes are in mm: carpe_label() = carpe_pt() / ggplot2::.pt
carpe_label <- function(size = "medium", ...) carpe_pt(size, ...) / ggplot2::.pt

theme_carpe <- function(base_size = carpe_pt("small"), base_family = carpe_register_font(), grid = c("x", "y", "xy", "none")) {
  grid <- match.arg(grid)
  ink <- carpe_pal$ink
  t <- ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.background  = ggplot2::element_rect(fill = carpe_pal$bg, colour = NA),
      panel.background = ggplot2::element_rect(fill = carpe_pal$bg, colour = NA),
      text             = ggplot2::element_text(colour = ink),
      axis.text        = ggplot2::element_text(colour = "#d0d0d0", size = base_size),
      axis.title       = ggplot2::element_text(colour = "#d0d0d0", size = base_size),
      plot.title       = ggplot2::element_blank(),     # the slide carries the headline, not the chart
      plot.subtitle    = ggplot2::element_blank(),
      plot.caption     = ggplot2::element_text(colour = "#8a8a8a", size = base_size),
      strip.text       = ggplot2::element_text(colour = ink, face = "bold", size = base_size),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = carpe_pal$grid, linewidth = 0.4),
      legend.position  = "none",         # label directly; a legend is reading work
      plot.margin      = ggplot2::margin(30, 40, 30, 30)
    )
  if (grid == "x")    t <- t + ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
  if (grid == "y")    t <- t + ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
  if (grid == "none") t <- t + ggplot2::theme(panel.grid.major = ggplot2::element_blank())
  t
}

# Collapse a grouping variable to "highlight" vs "other" (the one-accent rule, R19).
carpe_highlight <- function(x, keep) {
  factor(ifelse(as.character(x) %in% keep, "highlight", "other"), levels = c("other", "highlight"))
}

scale_colour_carpe <- function(...) {
  ggplot2::scale_colour_manual(values = c(highlight = carpe_pal$accent, other = carpe_pal$dim),
                               guide = "none", drop = FALSE, ...)
}
scale_fill_carpe <- function(...) {
  ggplot2::scale_fill_manual(values = c(highlight = carpe_pal$accent, other = carpe_pal$dim),
                             guide = "none", drop = FALSE, ...)
}

# Every word the chart puts on screen. Continuous-axis tick numbers are not counted (they are
# reading aids, not claims); discrete tick labels, titles, strips and text/label geoms are.
carpe_plot_text <- function(plot) {
  b <- ggplot2::ggplot_build(plot)
  labs <- unlist(plot$labels[intersect(names(plot$labels), c("title", "subtitle", "caption", "x", "y"))])
  geoms <- unlist(lapply(b$data, function(d) if ("label" %in% names(d)) unique(as.character(d$label))))
  pp <- b$layout$panel_params[[1]]
  ticks <- unlist(lapply(c("x", "y"), function(a) {
    sc <- b$layout$panel_scales_x[[1]]; if (a == "y") sc <- b$layout$panel_scales_y[[1]]
    if (!is.null(sc) && sc$is_discrete()) as.character(pp[[a]]$get_labels()) else NULL
  }))
  lay <- b$layout$layout
  strips <- unlist(lapply(setdiff(names(lay), c("PANEL", "ROW", "COL", "SCALE_X", "SCALE_Y", "COORD")),
                          function(v) unique(as.character(lay[[v]]))))
  txt <- c(labs, geoms, ticks, strips)
  txt <- txt[!is.na(txt) & nzchar(txt)]
  list(text = unname(txt), words = sum(lengths(strsplit(trimws(txt), "\\s+"))))
}

# 1920x1080 PNG via ragg (p. 75: at least the slide's pixel width; 1920 today) + word sidecar.
save_slide_fig <- function(plot, file, width = 1920, height = 1080, dpi = 144) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(file, plot, device = ragg::agg_png, width = width, height = height,
                  units = "px", dpi = dpi, bg = carpe_pal$bg)
  w <- carpe_plot_text(plot)
  jsonlite::write_json(w, sub("\\.png$", ".json", file), auto_unbox = TRUE, pretty = TRUE)
  if (w$words > 7) message(sprintf("%s puts %d words on screen (> 7): cut, or plan a PAUSE (p. 44)", basename(file), w$words))
  invisible(file)
}

# Markdown for a chart slide that carries its word count to the audit:  `r carpe_fig("figures/x.png")`
carpe_fig <- function(path, alt = NULL) {
  side <- sub("\\.png$", ".json", path)
  n <- if (file.exists(side)) jsonlite::read_json(side)$words else NA
  if (is.na(n)) warning("no sidecar for ", path, "; re-save it with save_slide_fig()")
  sprintf('![](%s){data-carpe-words="%s"%s}', path, ifelse(is.na(n), "", n),
          if (is.null(alt)) "" else sprintf(' fig-alt="%s"', alt))
}
