# carpe_vendor.R: give a project its own copy of the Carpe Audience helpers, so the deck renders
# (and its figures rebuild) without the skill installed. Run once when a talk starts, and again
# after a skill update you want (it overwrites the copy).
#
#   Rscript "$CARPE_SKILL/assets/carpe_vendor.R" [project_dir]        # default: the current directory
#   source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "carpe_vendor.R"))
#   carpe_vendor("path/to/project")
#
# Writes <project_dir>/carpe/assets/ (a mirror of the skill's assets/: R helpers, scss, fonts, templates)
# and <project_dir>/carpe/README.md. Then, in the deck's first R chunk, BEFORE any source():
#
#   if (dir.exists("carpe/assets")) Sys.setenv(CARPE_SKILL = normalizePath("carpe"))   # path from the .qmd to carpe/
#
# Every Sys.getenv("CARPE_SKILL", ...) in the helpers, nested sources included, then reads the local copy.
# The templates already carry that line. Commit or sync carpe/ with the project; it is about 600 KB.
#
# Numbers: a deck whose facts.R pulls from restricted results should also freeze its `f` list (see SKILL.md,
# "Rendering without the skill"), because carpe_pull() needs those files.

carpe_vendor <- function(project_dir = ".") {
  skill <- path.expand(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"))
  src <- file.path(skill, "assets")
  stopifnot("skill assets not found; set CARPE_SKILL" = dir.exists(src))
  dest <- file.path(project_dir, "carpe")
  dir.create(dest, showWarnings = FALSE, recursive = TRUE)
  unlink(file.path(dest, "assets"), recursive = TRUE)
  ok <- file.copy(src, dest, recursive = TRUE)
  stopifnot("copy failed" = ok)
  n <- length(list.files(file.path(dest, "assets"), recursive = TRUE))
  writeLines(c(
    "# carpe/",
    "",
    sprintf("A copy of the Carpe Audience skill's assets/, taken %s from %s (%d files).", format(Sys.Date()), skill, n),
    "It lets this project render without the skill installed. Do not edit it here: change the skill, then",
    "re-run `Rscript <skill>/assets/carpe_vendor.R <project_dir>` to refresh the copy.",
    "",
    "Use: the deck's first R chunk sets `Sys.setenv(CARPE_SKILL = normalizePath(\"<path to>/carpe\"))` before any",
    "`source()`, so every helper (including ones that source each other) reads this copy."
  ), file.path(dest, "README.md"))
  message(sprintf("carpe_vendor: %d files copied to %s", n, normalizePath(dest)))
  invisible(dest)
}

if (sys.nframe() == 0) {
  a <- commandArgs(trailingOnly = TRUE)
  carpe_vendor(if (length(a)) a[[1]] else ".")
}
