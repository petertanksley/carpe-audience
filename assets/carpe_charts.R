# carpe_charts.R — chart choice, chart patterns, motion and pie builds (Keyes 2011, pp. 79-81, 91)
#
#   source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "carpe_charts.R"))
#
# carpe_chart_choose()  Keyes's decision order: would one number do? -> what is the point? ->
#                       the chart type from his p. 81 table -> the 100% test for pies -> no stacked bars.
# carpe_lollipop()      estimates against a reference line (PMR/SMR/RR vs 100 or 1), one accent.
# carpe_trend()         a line over time against a reference, highlighted series labelled at the end.
# carpe_bars()          ranked bars, one accent, value labels.
# carpe_motion()        "Motion" (Godin via Keyes, p. 80): frames on IDENTICAL axes (checked),
#                       where it was -> where it is / is going; frame 1's notes establish the source
#                       and its validity. Slide change with a fade, never an animated morph (p. 91).
# carpe_pie_build()     Keyes's pie sequence (p. 80): topic -> the point slice and its number ->
#                       the rest of the slices -> a separate close number. Refuses when the parts
#                       do not sum to 100%.
#
# Every saved frame goes through save_slide_fig() (word sidecar) and lands in the deck through
# carpe_fig(), so chart words count against the seven-word rule. Pass `count` to the pattern
# helpers to enforce the data floors on every plotted estimate.

carpe_assets <- file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets")
source(file.path(carpe_assets, "theme_carpe.R"))
if (!exists(".carpe_slide")) source(file.path(carpe_assets, "carpe_generators.R"))

# ---- choosing --------------------------------------------------------------
carpe_chart_choose <- function(point = c("comparison", "ranking", "trend", "peak", "summation", "part-to-whole",
                                         "deviation", "distribution", "correlation"),
                               n_values = NULL, sums_to_100 = NA, change_over_time = FALSE) {
  point <- match.arg(point)
  msg <- character()
  if (!is.null(n_values) && n_values <= 2)
    msg <- c(msg, "Would one number do? With <= 2 values, a .big number slide (or a contrast pair) usually beats a chart (p. 79).")
  rec <- switch(point,
    comparison = "bars or columns (or a lollipop against a reference line for ratios)",
    ranking    = "ranked bars; or a statistical series of ordinals if the ranking ends somewhere surprising (p. 64)",
    trend      = "a line; points on the line for individual values; columns to compare periods",
    peak       = "a line with the peak highlighted",
    summation  = "one big number; a single bar built for scale if the size needs context (pp. 36-37)",
    `part-to-whole` = if (isTRUE(sums_to_100)) "a pie built in Keyes's sequence (carpe_pie_build), or bars" else
                        "bars: the parts do not sum to 100%, so a pie would mislead (p. 80)",
    deviation  = "lines or bars around a reference line (carpe_lollipop for ratios)",
    distribution = "columns or a line for shape (histogram bins count as discrete, so data floors apply)",
    correlation = "a scatterplot with a trend line")
  msg <- c(msg, sprintf("Point: %s -> %s (Keyes p. 81, after Few).", point, rec))
  if (change_over_time) msg <- c(msg, "Change is the point: use motion, two frames on the same axes, where it was -> where it is (p. 80).")
  msg <- c(msg, "Never stacked bars (\"rattlesnakes\", p. 80). One point per chart; detail goes to the handout or backup.")
  message(paste("-", msg, collapse = "\n"))
  invisible(rec)
}

.check_floor <- function(d, count, floor) {
  if (is.null(count)) return(invisible())
  bad <- d[[count]] < floor
  if (any(bad, na.rm = TRUE)) stop(sprintf("%d plotted estimate(s) rest on fewer than %d (column %s); drop or suppress them first",
                                          sum(bad, na.rm = TRUE), floor, count))
}

# ---- patterns ----------------------------------------------------------------
# d: data frame; est = estimate column; label = category column; highlight = value(s) of label to
# accent; ref = reference value (100 for x100 ratios, 1 for raw ratios); facet = optional column.
carpe_lollipop <- function(d, est, label, highlight, ref = 100, facet = NULL, limits = NULL,
                           value_labels = c("highlight", "all", "none"), count = NULL, floor = 20) {
  value_labels <- match.arg(value_labels)
  .check_floor(d, count, floor)
  d$.hl <- carpe_highlight(d[[label]], highlight)
  d$.lab <- d[[label]]; d$.est <- d[[est]]
  lim <- limits %||% c(min(0, min(d$.est)), max(d$.est) * 1.25)
  pad <- diff(lim) * 0.06
  lab_d <- switch(value_labels, highlight = d[d$.hl == "highlight", ], all = d, none = d[0, ])
  p <- ggplot2::ggplot(d, ggplot2::aes(.est, .lab, colour = .hl)) +
    ggplot2::geom_vline(xintercept = ref, colour = carpe_pal$ink, linewidth = 0.9) +
    ggplot2::geom_segment(ggplot2::aes(x = ref, xend = .est, yend = .lab), linewidth = 2.5) +
    ggplot2::geom_point(size = 11) +
    ggplot2::geom_text(data = lab_d, ggplot2::aes(x = .est + ifelse(.est >= ref, pad, -pad), hjust = ifelse(.est >= ref, 0, 1),
                                                  label = round(.est)), size = carpe_label("medium"),
                       family = "Barlow Condensed Carpe", fontface = "bold") +
    scale_colour_carpe() + ggplot2::scale_x_continuous(limits = lim, breaks = NULL) +
    ggplot2::coord_cartesian(clip = "off") + ggplot2::labs(x = NULL, y = NULL) + theme_carpe(grid = "none")
  if (!is.null(facet)) p <- p + ggplot2::facet_wrap(facet)
  p
}

carpe_trend <- function(d, x, y, group, highlight, ref = NULL, limits_y = NULL, count = NULL, floor = 20) {
  .check_floor(d, count, floor)
  d$.x <- d[[x]]; d$.y <- d[[y]]; d$.g <- d[[group]]; d$.hl <- carpe_highlight(d$.g, highlight)
  ends <- d[d$.x == max(d$.x) & d$.hl == "highlight", ]
  p <- ggplot2::ggplot(d, ggplot2::aes(.x, .y, group = .g, colour = .hl))
  if (!is.null(ref)) p <- p + ggplot2::geom_hline(yintercept = ref, colour = carpe_pal$ink, linewidth = 0.9)
  p + ggplot2::geom_line(linewidth = 2.5) + ggplot2::geom_point(size = 5) +
    ggplot2::geom_text(data = ends, ggplot2::aes(label = .g), hjust = -0.15, size = carpe_label("small") * 1.6,
                       family = "Barlow Condensed Carpe", fontface = "bold") +
    scale_colour_carpe() +
    ggplot2::scale_x_continuous(breaks = range(d$.x), expand = ggplot2::expansion(mult = c(0.03, 0.25))) +
    ggplot2::scale_y_continuous(limits = limits_y %||% c(0, max(d$.y) * 1.15), breaks = ref) +
    ggplot2::coord_cartesian(clip = "off") + ggplot2::labs(x = NULL, y = NULL) + theme_carpe(grid = "none")
}

carpe_bars <- function(d, value, label, highlight, percent = FALSE, limits = NULL, count = NULL, floor = 10) {
  .check_floor(d, count, floor)
  d$.v <- d[[value]]; d$.lab <- stats::reorder(d[[label]], d$.v); d$.hl <- carpe_highlight(d[[label]], highlight)
  fmt <- if (percent) function(v) paste0(round(100 * v), "%") else function(v) format(round(v), big.mark = ",")
  ggplot2::ggplot(d, ggplot2::aes(.v, .lab, fill = .hl)) +
    ggplot2::geom_col(width = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = fmt(.v)), hjust = -0.15, size = carpe_label("medium"), colour = carpe_pal$ink,
                       family = "Barlow Condensed Carpe", fontface = "bold") +
    scale_fill_carpe() +
    ggplot2::scale_x_continuous(limits = limits %||% c(0, max(d$.v) * 1.3), breaks = NULL, expand = ggplot2::expansion(0)) +
    ggplot2::coord_cartesian(clip = "off") + ggplot2::labs(x = NULL, y = NULL) + theme_carpe(grid = "none")
}

# ---- motion --------------------------------------------------------------------
# frames: named list of ggplots built with the SAME limits (pass limits/limits_y to the pattern).
# The axes are compared after building; any difference stops the build (geom_col() trains its
# axis on bar edges, so frames built separately drift). Returns slide markdown; emit with #| output: asis.
carpe_motion <- function(frames, dir, stem, story = "Motion", heading = "", source_note = "[Source and why it is valid.]",
                         say = NULL, runtimes = 20) {
  rng <- lapply(frames, function(p) { b <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]
                                      list(x = b$x.range %||% b$x$continuous_range, y = b$y.range %||% b$y$continuous_range) })
  same <- vapply(rng, function(r) isTRUE(all.equal(r, rng[[1]], tolerance = 1e-9)), logical(1))
  if (!all(same)) stop("carpe_motion: frames ", paste(names(frames)[!same], collapse = ", "),
                       " do not share frame 1's axes. Pass the same limits to every frame (p. 80).")
  runtimes <- rep_len(runtimes, length(frames))
  out <- ""
  for (i in seq_along(frames)) {
    f <- file.path(dir, sprintf("%s_%d.png", stem, i))
    save_slide_fig(frames[[i]], f)
    notes <- if (i == 1) paste("Establish the frame before the change: what this is, where it comes from, why it is sound.", source_note)
             else say[i] %||% sprintf("Advance. Same axes: what moved from frame %d to frame %d. [beat]", i - 1, i)
    if (i == 1 && !is.null(say[1])) notes <- paste(notes, say[1])
    out <- paste0(out, .carpe_slide("chart", carpe_fig(f), notes, "Background", story, runtimes[i], heading = heading))
  }
  out
}

# ---- pie build -------------------------------------------------------------------
# d: categories and their values (counts or shares); focus = the category that is the point.
# close = an optional carpe_fact for the separate close slide (his Safe2Tell total, p. 80).
# whole = the total the parts must make up (required for counts: the parts must BE the whole).
carpe_pie_build <- function(d, value, label, focus, dir, stem, topic, story = "Pie", whole = NULL,
                            close = NULL, close_style = "int", close_label = "", tol = 0.01) {
  v <- d[[value]]; shares <- v / sum(v)
  ok <- if (all(v <= 1)) abs(sum(v) - 1) <= tol
        else if (!is.null(whole)) abs(sum(v) - whole) <= tol * whole
        else abs(sum(v) - 100) <= 100 * tol
  if (!ok) stop("carpe_pie_build: the parts do not sum to the whole (100%); a pie would mislead (p. 80). ",
                "Use carpe_bars(), or pass whole = <total> if these are counts that do make it up.")
  d$.lab <- factor(d[[label]], levels = d[[label]]); d$.share <- shares; d$.hl <- carpe_highlight(d[[label]], focus)
  base <- function(dd, alpha_other) ggplot2::ggplot(dd, ggplot2::aes(x = 1, y = .share, fill = .hl, alpha = .hl)) +
    ggplot2::geom_col(width = 1, colour = carpe_pal$bg, linewidth = 1.5) +
    ggplot2::coord_polar(theta = "y", direction = -1, start = 0) +
    ggplot2::scale_alpha_manual(values = c(other = alpha_other, highlight = 1), guide = "none") +
    scale_fill_carpe() + ggplot2::xlim(0.5, 2.05) + ggplot2::labs(x = NULL, y = NULL) + theme_carpe(grid = "none") +
    ggplot2::theme(axis.text = ggplot2::element_blank())
  pct <- function(x) paste0(round(100 * x), "%")
  f2 <- base(d, 0) + ggplot2::geom_text(data = d[d$.hl == "highlight", ], ggplot2::aes(x = 1.85, label = pct(.share)),
                                        position = ggplot2::position_stack(vjust = 0.5), size = carpe_label("medium"),
                                        colour = carpe_pal$ink, family = "Barlow Condensed Carpe", fontface = "bold", alpha = 1)
  f3 <- base(d, 1) + ggplot2::geom_text(ggplot2::aes(x = 1.85, label = .lab), position = ggplot2::position_stack(vjust = 0.5),
                                        size = carpe_label("small") * 1.6, colour = carpe_pal$ink,
                                        family = "Barlow Condensed Carpe", fontface = "bold", alpha = 1)
  out <- .carpe_slide("medium", topic, "[Name what the whole is. Nothing else yet.]", "Set the Stage", story, 5)
  fp <- file.path(dir, sprintf("%s_point.png", stem)); save_slide_fig(f2, fp)
  out <- paste0(out, .carpe_slide("chart", carpe_fig(fp), sprintf("The point: %s, %s. [beat]", focus, pct(shares[d[[label]] == focus])),
                                  "Background", story, 10))
  fa <- file.path(dir, sprintf("%s_all.png", stem)); save_slide_fig(f3, fa)
  out <- paste0(out, .carpe_slide("chart", carpe_fig(fa), "Fill in the rest. [Name the other slices briefly.]", "Background", story, 15))
  if (!is.null(close))
    out <- paste0(out, .carpe_slide("big", sprintf("%s [%s]{.label}", carpe_number(close, close_style, name = close_label), close_label),
                                    "The close: [one line, e.g. \"We're pretty proud of that.\"]", "Background", story, 8))
  out
}
