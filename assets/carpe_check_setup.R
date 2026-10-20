#!/usr/bin/env Rscript
# carpe_check_setup.R — is this machine ready for the carpe-audience skill?
#   Rscript ~/.claude/skills/carpe-audience/assets/carpe_check_setup.R [--install]
# R packages, Quarto, Chrome and the Gemini key are per machine. --install installs missing CRAN packages and bananarama from GitHub.

pkgs <- c("ggplot2", "ragg", "systemfonts", "magick", "png", "jpeg", "xml2", "rvest", "jsonlite",
          "yaml", "dplyr", "tidyr", "stringr", "purrr", "rlang", "knitr", "scales", "ellmer", "remotes")
have <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
ok <- function(x, msg) cat(sprintf("[%s] %s\n", if (isTRUE(x)) " ok " else "MISS", msg))

for (p in pkgs) ok(have[[p]], paste("R package", p))
bn <- requireNamespace("bananarama", quietly = TRUE); ok(bn, "R package bananarama (GitHub: hadley/bananarama; images mode only)")
if ("--install" %in% commandArgs(TRUE)) {
  miss <- pkgs[!have]; if (length(miss)) install.packages(miss, repos = "https://cloud.r-project.org")
  if (!bn) remotes::install_github("hadley/bananarama")
}
skill <- path.expand(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"))
ok(file.exists(file.path(skill, "assets", "fonts", "BarlowCondensed-ExtraBold.ttf")), paste("skill + fonts at", skill))
ok(nzchar(Sys.which("quarto")) || file.exists("/Applications/quarto/bin/quarto"), "Quarto")
ok(file.exists("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"), "Google Chrome (headless screenshots)")
ok(nzchar(Sys.getenv("GEMINI_API_KEY")), "GEMINI_API_KEY in ~/.Renviron (images mode only; value not shown)")
if (!nzchar(Sys.getenv("GEMINI_API_KEY")))
  cat("       optional: only AI slide images need it; setup steps in the README, \"Setting up AI images\"\n")
rw <- path.expand("~/.claude/skills/render-word/apa-reference.docx"); ok(file.exists(rw), "render-word house style (optional: handout --docx falls back to pandoc defaults)")
