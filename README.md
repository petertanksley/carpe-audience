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

## Under the hood

The skill is a set of instructions plus a toolkit. Claude does the judgment work; the tools do the
rendering, the measuring and the checking.

| Layer | Tool | What it does here | Needed? |
|-------|------|-------------------|---------|
| Rules | Keyes's *Carpe Audience* (`references/carpe_rules.md`) | The style itself: seven words, no bullets, one font in three sizes, call to action first, stories typed and timed. Every check in the audit cites a page. | Always |
| Orchestration | Claude Code (`SKILL.md`) | Reads the rules, runs the plan / build / convert / audit conversation, writes the story into the notes, and decides what goes on screen. | Always |
| Slides | Quarto RevealJS + the bundled theme (`template.qmd`, `carpe.scss`, Barlow Condensed) | Turns Markdown into the deck: black background, white type, top-left registration, one fade transition, all assets embedded so the deck runs offline. | Always |
| Numbers | R + knitr inline code (`carpe_numbers.R`, `check_numbers.R`) | Pulls every number from a results file with its provenance, formats it the way Keyes puts numbers on screen ("1 in 7", "two-thirds higher"), and logs it so the audit can trace it. | For data talks |
| Charts | R + ggplot2, ragg, systemfonts (`theme_carpe.R`, `carpe_charts.R`) | Slide-scale charts: one accent on grey, direct labels, motion frames on identical axes, pies built a slice at a time. | For charts |
| Photos | R + magick (`carpe_images.R`) | Crops a photo so its focal point sits on a thirds line and bakes in a fade-to-black vignette for type to sit on. | For photo slides |
| AI images | [bananarama](https://github.com/hadley/bananarama) + Google Gemini's image model ("Nano Banana"), via ellmer | Generates slide images from text prompts. The template (`bananarama.yaml`) carries Keyes's image rules and safe-messaging rules for sensitive topics. Costs money per image. | Optional |
| Audit | R + xml2 / rvest (`audit_deck.R`) | Reads the **rendered** HTML and measures it: words per slide, type sizes, transitions, image resolution, pacing from the runtimes in the notes. | Always |
| Screenshots | Headless Google Chrome | Captures every slide so layout problems (overflow, type over a face) get seen, not assumed. | Recommended |
| Handout | pandoc (bundled with Quarto) (`carpe_handout.R`) | Builds Keyes's handout from the deck: notes with action items, every number with its exact value, questions, resources. Markdown or Word. | Optional |

## Requirements

- [Claude Code](https://claude.com/claude-code)
- R with the packages listed by `assets/carpe_check_setup.R` (ggplot2, ragg, magick, xml2, dplyr and friends)
- [Quarto](https://quarto.org) (it bundles pandoc)
- Google Chrome, for headless slide screenshots
- Optional, for AI images: the [bananarama](https://github.com/hadley/bananarama) R package and a Google
  Gemini API key (see "Setting up AI images" below).

## Install

```bash
git clone https://github.com/petertanksley/carpe-audience.git
cd carpe-audience
./install.sh            # copies into ~/.claude/skills/carpe-audience; re-run to update
# or: ./install.sh --link   symlink back to this checkout so `git pull` updates in place
Rscript ~/.claude/skills/carpe-audience/assets/carpe_check_setup.R --install
```

Start a new Claude Code session and run `/carpe-audience plan`, or just ask for a talk.

## Setting up AI images (optional)

Everything except AI image generation works without this. Skip it if you will use your own photos.

1. **Get a key.** Sign in to [Google AI Studio](https://aistudio.google.com/apikey) and create an API key.
2. **Enable billing, then cap it.** Gemini's image models need a billing-enabled Google Cloud project
   (check [Google's pricing page](https://ai.google.dev/gemini-api/docs/pricing) for current rates; it
   has been a few cents an image). Set a **spend cap** on the project in AI Studio so a mistake can't run
   up a bill.
3. **Store the key where R finds it,** never in a script, a repo or a chat. In R:
   `usethis::edit_r_environ()`, add a line `GEMINI_API_KEY=your-key-here`, save, and restart R.
4. **Install bananarama:** `Rscript ~/.claude/skills/carpe-audience/assets/carpe_check_setup.R --install`
   installs it with the other packages.
5. **Test it:**

   ```bash
   Rscript -e 'ellmer::chat_google_gemini()$chat("pong")'
   ```

   A reply means the key works. Run this ping before any image batch: when a project hits its spend cap,
   bananarama can hang silently for about ten minutes instead of failing, and the ping fails at once.

The skill always states the number of images and the estimated cost and asks before it generates
anything.

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
