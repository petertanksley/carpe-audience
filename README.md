# carpe-audience: a talk-design skill for Claude Code

A Claude Code skill that builds, converts, and audits research talks in the style of John-Michael
Keyes's *Carpe Audience: Give Better Presentations Despite PowerPoint* (2011). Slides carry a word, a
number, or an image: seven words at most, no bullets, white type on black, one font in three sizes,
anchored in the same place on every slide. The speaker carries the story, and the story lives in the
presenter notes.

Keyes wrote for school-safety talks to police, educators and funders. This skill keeps his rules as
faithfully as it can and adds what a research talk needs on top: numbers that trace back to their
source, slide-scale charts, backup slides for the methods questions, and a handout built from the deck.

## Credit

The ideas are Keyes's. This skill paraphrases his rules (with page numbers, in
`references/carpe_rules.md`) so Claude can apply and check them. It does not reproduce the book, and it
is not affiliated with or endorsed by the author. Read the book, a free download from the
[I Love U Guys Foundation](https://iloveuguys.org/downloads/Carpe-Audience.pdf): the reasoning and the stories behind the rules are the good part.

Built at the ALERRT Center at Texas State University, where Carpe Audience is the house style for talks.

## What it does

| Mode | What happens |
|------|--------------|
| `plan` | Keyes's process before any slide exists: audience and format, call to action first, stories written as prose, a cadence worksheet, napkin storyboards. |
| `build` | Plan to a Quarto RevealJS deck from the template: big numbers, claims, photo and split slides, Power Lists, charts, a call-to-action close. |
| `convert` | An existing bullet deck to Carpe: re-napkin each story, move every sentence into the notes, nothing dropped silently. |
| `audit` | A mechanical audit of the rendered deck against the book (word counts, registration, transitions, image resolution, pacing from the notes' runtimes), plus a number-provenance check. |
| `figure` | Slide-scale ggplot2 charts: `theme_carpe()`, one accent on grey, direct labels, motion frames on identical axes, built pies. |
| `images` | Photo prep (crop to the thirds, fade-to-black vignette) and optional AI slide images through Google Gemini. |

Numbers are built, not typed: each one is pulled from a results file with its provenance, written into the
slides as inline R, and logged to a ledger the audit checks. Optional data floors (default: estimates
need 20 underlying cases, counts need 10) refuse to put an unreliable or disclosive number on screen; set
them for your own data's rules.

## Requirements

- [Claude Code](https://claude.com/claude-code)
- R with the packages listed by `assets/carpe_check_setup.R` (ggplot2, ragg, magick, xml2, dplyr and friends)
- [Quarto](https://quarto.org) (it bundles pandoc)
- Google Chrome, for headless slide screenshots
- Optional, for AI images: the [bananarama](https://github.com/hadley/bananarama) R package and a
  `GEMINI_API_KEY` in `~/.Renviron`. Generation costs money (roughly $0.07 an image); the skill states the
  count and cost and asks before every run.

## Install

```bash
git clone https://github.com/petertanksley/carpe-audience.git
cd carpe-audience
./install.sh            # copies into ~/.claude/skills/carpe-audience; re-run to update
# or: ./install.sh --link   symlink back to this checkout so `git pull` updates in place
Rscript ~/.claude/skills/carpe-audience/assets/carpe_check_setup.R --install
```

Start a new Claude Code session and run `/carpe-audience plan`, or just ask for a talk.

## What's inside

| Path | Role |
|------|------|
| `SKILL.md` | The skill: non-negotiables, modes, and how the helpers fit together. |
| `references/carpe_rules.md` | Keyes's 45 rules, 14-step process, numbers-and-charts patterns and 20-item audit checklist, paraphrased with page cites. |
| `assets/template.qmd`, `carpe.scss`, `carpe-fonts.css`, `fonts/` | The deck template and theme. |
| `assets/theme_carpe.R`, `carpe_charts.R` | Slide-scale ggplot2 theme and chart patterns. |
| `assets/carpe_numbers.R`, `carpe_generators.R`, `check_numbers.R` | Numbers by construction, Keyes's numeric sequences, and the provenance check. |
| `assets/audit_deck.R` | The mechanical audit of a rendered deck. |
| `assets/carpe_backup.R`, `carpe_handout.R` | Backup slides and the handout. |
| `assets/carpe_images.R`, `bananarama.yaml` | Photo preparation and the Gemini image template. |

## License

MIT for the code and text (`LICENSE`). The Barlow Condensed fonts in `assets/fonts/` are under the SIL
Open Font License (`assets/fonts/OFL.txt`).
