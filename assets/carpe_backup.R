# carpe_backup.R — backup slides and links (Keyes's sweat-lodge advice, pp. 31-32, 103-105)
#
#   source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "carpe_backup.R"))
#
# Research talks get methods questions. The answer lives on a backup slide after the close: the
# CIs, the model, the full table. The main slide carries a tiny grey link to it, and the backup
# carries one back. The audience never sees the backup unless asked; the presenter can also jump
# there with RevealJS overview (O). Backup slides are exempt from the seven-word count and are
# reported, not scored, by the audit.
#
#   On the main slide:      `r carpe_link("bk-ci")`
#   After the close:        ```{r}  #| output: asis
#                           cat(carpe_backup_section())
#                           cat(carpe_backup("bk-ci", "Suicide PMRs with 95% CIs", tab, back = "only-suicide"))
#                           ```
# `back` is the id of the main slide (Quarto derives it from the heading, or set {#id} on it).

carpe_link <- function(id, text = "→") sprintf('[%s](#%s){.carpe-link}', text, id)   # Quarto rewrites #id to #/id itself

carpe_backup_section <- function(title = "Backup") sprintf('# %s {.backup visibility="uncounted"}\n\n', title)

# body: a data frame (rendered as a pipe table), a character string of markdown, or a figure path.
carpe_backup <- function(id, title, body, back = NULL, digits = 1, note = NULL) {
  md <- if (is.data.frame(body)) paste(knitr::kable(body, format = "pipe", digits = digits), collapse = "\n")
        else if (is.character(body) && length(body) == 1 && grepl("\\.(png|jpg|svg)$", body)) sprintf("![](%s)", body)
        else paste(body, collapse = "\n")
  paste0(sprintf('## %s {#%s .backup visibility="uncounted"}\n\n', title, id), md, "\n\n",
         if (!is.null(note)) paste0("[", note, "]{.small}\n\n") else "",
         if (!is.null(back)) paste0(carpe_link(back, "← back"), "\n\n") else "",
         "::: {.notes}\nBackup: answer the question, then go back.\nType: Background · Story: Backup · Runtime: 0 s\n:::\n\n")
}
