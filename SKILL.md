---
name: carpe-audience
description: Design, convert, or audit a talk in the Carpe Audience style (John-Michael Keyes, 2011), for academic and practitioner research talks. Slides carry a word, a number, or an image (seven words max, no bullets, white type on black, three sizes, top-left registration); the speaker carries the story in the notes. Builds Quarto RevealJS decks, slide-scale ggplot2 figures (theme_carpe), photo preparation (crop, vignette) and AI slide images via bananarama/Gemini, number provenance checks, and a mechanical deck audit. Use for any talk, panel, briefing, or lecture deck, and when reviewing any talk.
argument-hint: "[plan | build | convert | audit | figure | images] [deck or project path]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "AskUserQuestion"]
---

# Carpe Audience

*Carpe Audience: Give Better Presentations Despite PowerPoint* (Keyes, 2011) builds talks on a
newspaper metaphor: the slide is the headline, the speaker is the story. Keyes's running examples
are school-safety talks to police, educators and funders. The goal
of this skill is to reproduce his style **as faithfully as possible** while carrying research
results: numbers, charts, and the evidence behind them.

**Backbone:** `references/carpe_rules.md`: the book's 45 operational rules (R1 to R45) with page
cites, Keyes's 14-step process, a 20-item audit checklist, and his numbers-and-charts patterns.

Read the relevant sections before acting, and cite pages. The book is a free download from the
I Love U Guys Foundation (https://iloveuguys.org/downloads/Carpe-Audience.pdf) and worth reading in full; this
skill paraphrases it and does not reproduce it.

## The non-negotiables

1. **Call to action first** (p. 39). Write it in the deck YAML (`carpe: call-to-action:`) before
   any slide exists, with the allied organisations that support it (`carpe: allies:`). The talk
   ends on it or on a callback to the opening quote, never on "In summary" or a bare "Questions?"
   (pp. 27, 45).
2. **Seven words or fewer on screen, charts included** (p. 44). A quote or a long slide may run
   over only with a PAUSE cue: the speaker turns, reads silently, turns back (p. 100).
3. **No bullets on screen** (p. 63). A sequence becomes a **Power List**, one slide per step,
   never fragments (pp. 63–67, 91).
4. **The slide is the headline; the speaker is the story** (p. 19). The script lives in
   `::: {.notes}`, never repeated on screen (Mayer's redundancy effect, pp. 21, 26).
5. **Every slide's notes end with a tag line** (pp. 40–41, 90):
   `Type: <Call to Action | Background | Set the Stage | Break | Transition> · Story: <name> · Runtime: <N> s [est]`
   `est` marks a word-count estimate (about 150 wpm). Replace it with stopwatch time after
   rehearsal, and plan the slot at runtime x 1.10 (pp. 41, 93). A slide with no purpose is cut.
6. **Type: white on black, one family, three sizes (big / medium / small), anchored top-left,
   identical from slide to slide** (pp. 47, 52, 60–61, 91). No colour on type; colour comes from
   photographs (pp. 60, 90). No per-slide centring, no AutoFit (`.r-fit-text`, `.smaller`,
   inline font sizes), no ALL-CAPS emphasis. No headings unless the heading *is* the point (p. 45).
7. **Images: one per slide, never a montage** (p. 75). Full bleed, split (photo bleeding across
   two-thirds), or a single element on black (pp. 29, 75), with the focal point on a thirds line
   (p. 71). Type sits in the negative space with a soft shadow; use a fade-to-black vignette, not
   a wash-out (pp. 76–77). No clip art or handshakes (pp. 45, 66).
8. **Charts: one point, then less data, more point** (p. 79). First ask whether one number would
   do. Detail goes to the handout or a backup slide. "Motion" means frames on the same axes:
   where it was, then where it is or is going, with the source and its validity established on
   frame one (p. 80). Colour: Keyes picks "for drama" (p. 80); this skill adapts that to **one
   accent on grey, on chart marks only**.
9. **One transition, a fade of 0.5–1 s**, everywhere. Animate only physical movement (p. 91).

Keyes's timing numbers (30-second beats, 10-minute blocks) come from his stopwatch on TV newscasts
and from Medina's pop science, not from controlled data. Keyes himself calls it "cold, hard,
clinical science" (p. 14). That caveat is **this skill's**, not his; use it only if challenged.
Mayer's redundancy finding is the best-supported claim in the book.

## Assets (`assets/`)

| File | Purpose |
|---|---|
| `template.qmd` | Hook title slide, then `.big`, `.medium`, `.quote`, photo, `.split`, `.power` (highlight-the-fact frames), `.chart`, `.blank`, and a CTA close. YAML carries `carpe:` (call-to-action, allies, audience, format, slot, speaker, sources). |
| `carpe.scss`, `carpe-fonts.css`, `fonts/` | The theme: Barlow Condensed (SIL OFL), three size tokens, white/grey type, top-left registration, soft shadow on every photo slide, thirds-bleed split, `.grid-debug` thirds overlay. |
| `theme_carpe.R` | `theme_carpe()` (chart text at the deck's small size), `carpe_label()` (medium, for direct labels), `carpe_highlight()`, `scale_*_carpe()`, `save_slide_fig()` (1920x1080 plus a word-count sidecar), `carpe_fig()` (inserts a chart that carries its word count to the audit). |
| `carpe_images.R` | `carpe_promote()` (bananarama candidate to `images/*.jpg`), `carpe_crop()` (aspect and focal point; `aspect = "split"`), `carpe_vignette()` (fade to black baked into the pixels), `carpe_sync()` (refresh a talk's theme copies after a skill update). |
| `carpe_charts.R` | `carpe_chart_choose()` (Keyes's decision order, p. 81 table), patterns `carpe_lollipop()` / `carpe_trend()` / `carpe_bars()` (one accent, direct labels, floors enforced via `count =`), `carpe_motion()` (frames on identical axes, checked; source-and-validity first frame), `carpe_pie_build()` (topic → point slice → all slices → close; refuses parts that don't make the whole). |
| `carpe_backup.R` | `carpe_link()` (small grey jump to a backup slide), `carpe_backup_section()`, `carpe_backup()` (a table, figure or markdown on an uncounted backup slide with a link back). |
| `carpe_handout.R` | Builds Keyes's handout from the rendered deck: cover, notes table with napkin-word headings and an Action Items column, every number with what it is and its exact value (from the ledger), Questions, Resources, optional evaluation. `--docx` writes Word (house style if a render-word skill is installed); `--technical` adds file-and-filter provenance. |
| `carpe_generators.R` | Keyes's numeric sequences as slide markdown from facts: `carpe_series()` (statistical series, p. 64), `carpe_highlight_fact()` (p. 67), `carpe_number_story()` (derived-number build after "One in a Million", pp. 36–37). |
| `audit_deck.R` | Mechanical audit of the **rendered** HTML against the book (pages cited in the script). `--from/--to` audits one segment; `--cadence` writes Keyes's worksheet. |
| `carpe_numbers.R` | Numbers by construction: `carpe_pull()` (one value from a results file, with provenance and the data floors checked), `carpe_derive()`, `carpe_number()` / `n()` (slide language: `int`, `pct`, `one_in`, `ratio`, `ratio_words`, `ordinal`, `big_count`, `diff`, ...), `carpe_ledger_write()`. |
| `check_numbers.R` | Traces every number on screen and in the notes: by construction (the ledger), declared constants, or `carpe: sources:`. Reports ambiguous matches and floor failures. |
| `bananarama.yaml` | Gemini slide-image template with Keyes's image rules and the safe-messaging rules baked in. |

**New machine?** R packages, Quarto, Chrome and (for images) the Gemini key are per machine: `Rscript ~/.claude/skills/carpe-audience/assets/carpe_check_setup.R [--install]`.

Copy `template.qmd`, `carpe.scss`, `carpe-fonts.css` and `fonts/` into `talks/<name>/` (copies, never
symlinks, so an old talk keeps rendering the way it did). **After any skill update, run `carpe_sync("talks/<name>")`**: a
stale theme copy silently renders old rules (it can, for one, shrink every big number to label
size). Set `CARPE_SKILL=~/.claude/skills/carpe-audience` for the R helpers.

## Modes

### `plan`: before any slides

Keyes's process (`carpe_rules.md`, Process), interactively and briefly:

1. **Audience, format and version.** Who is coming and what they know. Campfire (linear) or
   sweat-lodge (boardroom: interruptions, a hyperlinked menu, two endings, pp. 31–32, 103–105).
   Keep versions per audience and time slot; story types tell you what to cut (pp. 32, 40, 89).
2. **Call to action, plus allies** (p. 39). Tiered if the room is mixed.
3. **Stories, written as prose away from the slides** (pp. 40–41). Each paragraph gets a type, a
   story name and a stopwatch time (or an `est`). Story typing also shows which background data
   must come *before* it is referenced (p. 41).
4. **Cadence worksheet** (pp. 35, 41, 91): Time / Story / Type / Slide, with stories of 2–5 min,
   about three per 10-minute block (long, then shorter), a hook at each 10-minute mark, a change
   of slide, pause or voice about every 30 s, and at least one rapid-fire run (3–5 slides in
   6–8 s).
5. **Napkins** (p. 43): for each slide, the at-most-seven words or the image idea. Nothing else.

Save as `talks/<name>/plan.md`, or into the project's `docs/logs/plans/`.

### `build`: plan to deck

Start from `template.qmd`. Notes come straight from the story prose. A number goes `.big`, a claim
`.medium`, an emotional beat a photo slide, a list a `.power` run, data a `.chart`. Render with
`quarto render <file>.qmd` (one file per call), then run `audit` and `check_numbers.R`, and
screenshot every slide (headless Chrome, `#/h/v` addressing, `--virtual-time-budget=25000` so the
embedded font loads; with `#` section dividers RevealJS builds vertical stacks, so address a
slide as `#/<stack>/<slide>`).

### `convert`: a bullet deck to Carpe

Re-napkin each story; don't keep the old headline by default, because it is usually a label (pp.
43–45, 90). Move every sentence into the notes, decide whether the slide is a big number, a photo,
a Power List or a cut, and add the tag line. Converting a list means combining, dropping and
re-sequencing items (p. 65). Never drop content silently: anything leaving the screen lands in the
notes or the handout.

### `audit`: score a deck

```bash
quarto render talks/<name>/<deck>.qmd
Rscript "$CARPE_SKILL/assets/audit_deck.R"   talks/<name>/<deck>.html [--from N --to M] --out talks/<name>/carpe_audit.md --cadence talks/<name>/cadence.csv
Rscript "$CARPE_SKILL/assets/check_numbers.R" talks/<name>/<deck>.html [--from N --to M] --out talks/<name>/carpe_numbers.md
```

Then review the judgment items the audit lists against the audit checklist in `carpe_rules.md`.
Treat the score as advisory, not a gate.

### Numbers by construction (every research talk)

A number on a slide or in the notes must *be* its source value, never a retyping of it.

1. Write `talks/<name>/facts.R`: one `carpe_pull()` per number, filtered to exactly one row of a
   saved results file. Given the underlying `count`, it refuses values below the data floors
   (default: estimates < 20, counts < 10; set `floors =` to your data's disclosure rules).
   Use `carpe_derive()` for arithmetic (differences, sums) so provenance survives.
2. In the deck's setup chunk, `source("facts.R")`. Write every number as inline R, on screen and
   in the notes: `` `r n(f$suicide_m, "ratio_words")` `` gives "two-thirds higher"; `"one_in"` gives
   "1 in 7" (adds "about" whenever rounding moves it more than 2%).
3. End the deck with a hidden chunk that calls `carpe_ledger_write()`. That writes
   `<deck>_numbers.csv`: every rendered number, its value and its source.
4. `check_numbers.R` reads the ledger. Declare definitional numbers (an age cutoff, a reference
   line) under `carpe: constants:`. Anything else must trace to `carpe: sources:`.

**Generators** (`carpe_generators.R`) build Keyes's numeric sequences from facts. Emit them from a
chunk with `#| output: asis` and `cat()`:

```r
cat(carpe_highlight_fact(topic = "Three causes. One bundle?", story = "The finding", style = "ratio",
      items = list(Suicide = f$suicide_m, Liver = f$liver_m, Poisoning = f$poison_m)))
cat(carpe_series(setup = "Male officer suicide, by year", items = f$yr_m, style = "ratio",
      punchline = 5, story = "Steady"))                      # 2 s a slide, 10 s on the punchline
cat(carpe_number_story(story = "Who", list(
  list(fact = f$deaths_all, style = "int", label = "officer deaths", runtime = 4),
  list(fact = f$share_le64, style = "one_in", label = "at 64 or younger", runtime = 5),
  list(text = "Reach them while they serve", runtime = 6))))   # last step = Call to Action
```

- **Highlight the fact:** topic → group unlit → each item lit with its statistic → group again.
- **Statistical series:** setup → one number per slide, fast → slow on the punchline. It forms a
  Keyes rapid-fire run by construction.
- **Number story:** a chain of derived numbers ending on the reframe.

Each slide's notes come with the spoken scaffold (statistic, `[Human example]`, statistic again)
and `est` runtimes. Replace the bracketed prompts with the real story.

**Use them strategically, not by default.** Each one spends a lot of the
room's attention, and repeated, they become a gimmick. As a rule of thumb, a 15–20 minute talk
gets at most one of each, placed where the argument turns:
- **Highlight the fact:** for the central finding, when a few parallel numbers *are* the point
  (only one of three causes elevated). Not for a supporting result.
- **Statistical series:** when the sequence carries the meaning, a ranking that ends somewhere
  surprising (Keyes's 48th) or a run that stays steady. It doubles as the talk's rapid-fire
  syncopation, so one is usually enough.
- **Number story:** as the bridge into the call to action, near the end.

Everywhere else, a single `.big` number, a chart, or a photo does the job.

Keyes's numeric patterns, for when you write the story (`carpe_rules.md`, Numbers and charts):
- **Every number is a story:** statistic, then a human example, then the statistic again (pp. 39, 67).
- **Units on screen:** ordinals for rankings, bare percentages, big counts as words ("30 Million"),
  contrast pairs ("Zero" / "Hundreds"), and a human-scale reframe ("One in a Million").
- **Numbers serve every story type,** Transitions and Calls to Action included (p. 41).

### `figure`: slide-scale charts in R

```r
source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "theme_carpe.R"))
p <- ggplot(d, aes(pmr, cause, colour = carpe_highlight(cause, "Suicide"))) +
  geom_vline(xintercept = 100, colour = "white") +
  geom_point(size = 9) +
  geom_text(aes(label = round(pmr)), nudge_x = 18, hjust = 0, size = carpe_label("medium"),
            family = "Barlow Condensed Carpe", fontface = "bold") +
  scale_colour_carpe() + labs(x = NULL, y = NULL) + theme_carpe(grid = "none")
save_slide_fig(p, "talks/<name>/figures/fig_main.png")     # also writes fig_main.json (word count)
```

**Choose before you plot** (`carpe_chart_choose(point, n_values, sums_to_100, change_over_time)`):
1. Would one number do? With two values or fewer, use a `.big` slide or a contrast pair (p. 79).
2. What is the point: trend, peak, comparison, summation, part-to-whole, deviation, distribution
   or correlation? It maps onto his p. 81 table.
3. A pie only when the parts make the whole, and then built in his sequence. Never stacked bars.
4. If change is the point, use motion.

**Patterns and builds** (`carpe_charts.R`; emit the builds from `#| output: asis` chunks):

```r
lim <- c(0, 300)                                                  # motion: one set of limits for every frame
cat(carpe_motion(list(
  men  = carpe_trend(d_men, "year", "pmr", "sex", "Men", ref = 100, limits_y = lim, count = "obs"),
  both = carpe_trend(d_all, "year", "pmr", "sex", c("Men", "Women"), ref = 100, limits_y = lim, count = "obs")),
  dir = "figures", stem = "trend", heading = "Five years. No spike.",
  source_note = "Every U.S. officer death certificate, 2020-2024, against other workers that year."))
cat(carpe_pie_build(comp, "obs", "cause", focus = "Suicide", whole = sum(comp$obs),
                    dir = "figures", stem = "pie", topic = "Male officer despair deaths"))
```

`carpe_motion()` stops if any frame's axes differ from frame 1's, and frame 1's notes open with the
source-and-validity beat. `carpe_lollipop()` handles estimates against a reference line (ratios
vs 100), and `carpe_bars()` handles ranked bars. Pass `count = "obs"` to any pattern to enforce
the floors on the plotted rows.

In the deck, insert it with `` `r carpe_fig("figures/fig_main.png")` `` on a `.chart` slide, so the
audit counts its words. Rebuild slide figures from analysis output rather than restyling
manuscript figures. Use plain-language labels, no legend, one accent, and fixed shared limits
across motion frames (set explicit shared `limits`: `geom_col()` trains its axis on bar edges, so
frames drift otherwise). Slide figures obey the paper's data floors, if it has any. Keep the figure script
in the project so the figures regenerate.

### `images`: photos and AI slide images

**Safe messaging comes first when a talk touches suicide:** images show absence, never the act or
method, and no funeral or despair clichés (rules in the YAML header). **Absence needs presence:**
an empty room reads as empty; show the group, row or occasion in use with one gap.

Copy `assets/bananarama.yaml` to the talk folder and write one entry per slide idea, describing the
metaphor rather than the statistic (Keyes's free association, p. 69). Ask for crop margin around
the subject (p. 71) and for negative space where the type will go. **Before running, state the
image count and the cost (about $0.07 per image) and get an explicit yes.** Ping Gemini first.
Generation budget: one round of n = 3 per idea; if nothing works, change the *metaphor*, not the
seed (p. 69's three-minute rule).

Prepare and place (`carpe_images.R`):

```r
carpe_promote("images/candidates/x-2.png", "x")                       # JPEG data in a .png name -> images/x.jpg
carpe_vignette("images/x.jpg", centre = c(0.3, 0.5))                  # -> images/x_vig.jpg (light on the subject)
carpe_crop("images/x.jpg", aspect = "split", focus = c(0.4, 0.5))     # -> images/x_crop.jpg for the split layout
```

```markdown
## {.right-third background-image="images/x_vig.jpg" background-size="cover" background-position="30% 50%"}
## {.split background-image="images/x_crop.jpg" background-size="auto 100%" background-position="left center" background-repeat="no-repeat"}
```

- Place type in the negative space with `.right`, `.left-half` / `.right-half` (48%) or
  `.left-third` / `.right-third` (31%). Use a third when the subject spans the middle, so the type
  never covers what the photo is about. A label beside a big number: `16 [men]{.label}`.
- Move the focal point onto a thirds line with `background-position` (p. 71). Check with the
  `.grid-debug` class in a screenshot.
- Prefer `carpe_vignette()` to `background-opacity`. Dimming washes out the deck's only colour
  source (p. 90); keep it as a last resort.
- **bananarama quirks:** files are JPEG data with a `.png` name (use `carpe_promote()`), frames are
  1376x768 (clears 1280, not 1920), and a shared `seed` makes the n candidates near-identical.
- Record AI generation in the notes and on a credits slide in the backup (pp. 120–123).
- `embed-resources: true` inlines background images; the deck stays offline-safe (p. 83).

## Backup slides (methods questions)

Keyes's sweat-lodge advice (pp. 31–32, 103–105): plan for interruptions and keep detail reachable
without putting it on the main line. For research talks, that means the CIs, the model, the full
table. Put them on backup slides after the close, each linked from the main slide it supports:

```r
# on the main slide:  ## Only suicide stands out {#only-suicide .chart}   ...   `r carpe_link("bk-pmr")`
cat(carpe_backup_section())                                         # after the close, #| output: asis
cat(carpe_backup("bk-pmr", "PMRs, male officers, 2020-2024", pmr_table, back = "only-suicide",
                 note = "PMR: share of deaths from a cause vs other workers of the same age and sex."))
```

Backup slides are uncounted, exempt from the seven-word count, and reported (not scored) by the
audit. The presenter can also reach them with RevealJS overview (O).

## Handout

Never hand out or email slide printouts, and send organisers the handout rather than the slides
(pp. 21–22, 103). Keyes's handout (pp. 107–113):
- a cover page: what the talk is, "you may not need to take notes", contact details;
- a notes page whose headings are the slides' napkin words, with an **Action Items** column;
- a Questions page;
- Resources: every resource cited;
- an evaluation;
- a program information sheet.

For research talks the full numbers, CIs and tables live here. Generate it from the deck:

```bash
Rscript "$CARPE_SKILL/assets/carpe_handout.R" talks/<name>/<deck>.html [--from N --to M] --docx [--technical]
```

It reads `carpe: speaker / contact / call-to-action / allies / resources / evaluation` from the
YAML, and the numbers table comes from the ledger. Give every fact a plain-language `label =` in
`facts.R`, so the handout says "Suicide, male officers (PMR; 100 = other workers)" rather than a
file name. Fill in the resources yourself; the generator never invents them. Hand it out at the end or as the last page. **For updates and briefings, the handout is a
prose report circulated in advance and cited by page during the talk** (p. 103).

## Integration

- Works standalone. A talk-building or talk-review agent can build to these rules and this
  template, and score with `audit_deck.R`, `check_numbers.R` and the audit checklist.
- Academic and practitioner talks follow the same rules. Caveats go in the notes, the backup and
  the handout, never on the main line. For practitioner audiences, cut method caveats from the
  slides entirely.
