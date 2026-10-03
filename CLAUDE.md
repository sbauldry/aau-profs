# AAU Sociology Full Professors Database

Builds and annually updates a database of full professors of sociology at AAU member universities.

## Stack

- R project, version-controlled on GitHub
- Scraping: `rvest`; `chromote` for JavaScript-rendered pages
- Structured extraction: `ellmer` with Claude
- Data management: tidyverse

## Source of truth

codebook.md is authoritative for the schema (tables, fields, value labels), inclusion rules, research-area vocabulary and coding rules, identity matching, validation, and the change log. This file summarizes; if the two disagree, codebook.md wins. Update codebook.md first, then bring this file into line.

## Data model

Panel structure; do not flatten.

- **people**: one row per person, stable `person_id` that persists across years.
- **snapshots**: keyed by `person_id` × `year` × `inst_id`. Fields: rank, title, institution, appointment type, research areas (raw), research areas (coded).

`inst_id` is a stable short institution code (e.g., `purdue`); see `institutions` in codebook.md. `year` is the collection year (not "wave").

Never reassign or recycle a `person_id`. Matching people across years should be conservative; send uncertain matches to hand review rather than guessing.

## Inclusion rules

Scope is tenured full professors only (tenure inferred from tenure-line Professor rank). Full rules and edge cases are in codebook.md §2.

Institutional frame: all AAU members, including the Canadian members (Toronto, McGill). University of Toronto is restricted to the St. George campus only.

- Include: tenured full professors, including named/distinguished professors, with a primary or formal joint appointment (budgeted share) in a sociology department. Administrators (heads, chairs, deans, etc.) and people with joint appointments in other units are included.
- Exclude but flag (`included = FALSE`, kept in the data so exclusions are auditable): emeriti, courtesy/affiliated/adjunct, non-tenure-line (clinical, teaching, research, practice), visiting, and administrators with no sociology faculty appointment.

## Pipeline stages

1. Verify seed URLs (AAU member list → sociology department faculty pages).
2. Scrape faculty pages.
3. Extract structured records with Claude via `ellmer`.
4. Code research areas to the controlled vocabulary (ASA sections). This is a separate step from extraction; never combine them. Research-area coding rules and the ASA section vocabulary are in codebook.md.
5. Diff against the prior year and hand-review only changes: new full professors, exits, rank changes.

## Conventions

- Write R code consistent with the design above. Prefer tidyverse style.
- Reproducibility: store every LLM prompt as a versioned file in the repo, and record the exact model ID and prompt version with each extraction and coding run.
- Comparability: flag any change that would break comparability across years (inclusion rules, field definitions, vocabulary, prompts, model version, ID matching) before making it, and log adopted changes with the year they take effect.
- Secrets: the Anthropic API key lives in `~/.Renviron` as `ANTHROPIC_API_KEY`. Never write keys into the repo.
- Git: commit in small, descriptive steps; push at the end of each session.

## Folder map

- `codebook.md`: schema, inclusion rules, ASA vocabulary, matching rules, change log (authoritative)
- `R/`: pipeline code, one script/function file per stage (verify, scrape, extract, code, diff)
- `prompts/extraction/`, `prompts/coding/`: versioned LLM prompt files (e.g., `extract_v1.md`)
- `data/seeds/`: dated copies of the AAU member list (from AAU's official members page) and verified faculty-directory URLs
- `data/raw_html/`: cached scraped pages (git-ignored; local only, not archived, not guaranteed recoverable)
- `data/interim/`: intermediate extraction/coding outputs
- `data/final/`: `institutions`, `people`, `snapshots`, `areas`, `changes` tables and `person_id_registry.csv`
- `validation/`: hand-coding and agreement results, year in file name
- `logs/`: run logs (model ID, prompt version) and comparability change log
- `output/`: reports and figures
- `renv/`, `renv.lock`: pinned package environment (`renv::restore()` to rebuild)
