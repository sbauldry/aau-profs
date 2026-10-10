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
- `R/`: pipeline code. Numbered scripts so far: `01_verify_seed_urls.R`, `02_discover_faculty_links.R`, `03_build_institutions_seed.R`, `04_check_js_pages.R` (stage 1); `05_test_extraction.R`, `06_test_profiles.R` (development tests of the extraction prompt); `extract_schema.R` (ellmer schema + `as_extract_tibble()`); stage 2 scraper: `scrape.R` (fetch, robots, rate limit, block detection, link-preserving text, chunking, pagination), `site_config.R` (per-institution method from the seed table), tests `07_scrape_test.R`, `08_scrape_profiles_test.R`
- `prompts/extraction/`, `prompts/coding/`: versioned LLM prompt files (e.g., `extract_v1.md`)
- `data/seeds/`: dated copies of the AAU member list (from AAU's official members page) and verified faculty-directory URLs
- `data/raw_html/`: cached scraped pages (git-ignored; local only, not archived, not guaranteed recoverable)
- `data/interim/`: intermediate extraction/coding outputs
- `data/final/`: `institutions`, `people`, `snapshots`, `areas`, `changes` tables and `person_id_registry.csv`
- `validation/`: hand-coding and agreement results, year in file name
- `logs/`: run records (date, model ID, prompt version, counts); the comparability change log is codebook.md §8
- `output/`: reports and figures
- `renv/`, `renv.lock`: pinned package environment (`renv::restore()` to rebuild)

## Setting up on a new machine

1. Clone the repo and open `aau-profs.Rproj` in RStudio (or start R in the folder). `renv` bootstraps itself; run `renv::restore()` to install the pinned packages.
2. Create `~/.Renviron` (never committed) with two lines, then restart R:
   - `ANTHROPIC_API_KEY=<your key>`
   - `SCRAPER_CONTACT=sgbauldry@gmail.com` (goes in the scraper user-agent; codebook §10)
3. Chrome or Chromium must be installed for `chromote`.
4. `data/raw_html/` is git-ignored and will be empty. Scripts `04`, `05` and `06` read cached pages from it; rerun `R/04_check_js_pages.R` (and `06`, which fetches its own profiles) to regenerate what they need.
5. Check that `Sys.getenv("SCRAPER_CONTACT")` and `nzchar(Sys.getenv("ANTHROPIC_API_KEY"))` look right before any scraping or API call.

## Status (as of 2026-10-05)

Codebook is at v0.1.15 (draft); the change log in codebook.md §8 records every decision so far. Nothing has been collected yet: the collection window is Oct 15 – Nov 15, 2026. All work to date is pre-collection setup and trial runs.

**Done**
- Project scaffolding, renv, folder structure, GitHub remote.
- Decisions recorded in the codebook: key = person × year × institution; scope = tenured full professors (administrators and joint appointees included); Canadian members included, Toronto = St. George only; fuzzy and cross-institution matches need hand review; raw HTML is not archived; `person_id` registry design; prompt versioning; pinned models (Sonnet 5.5 for extraction, Opus 5.5 for coding); scraping conduct rules; validation scoring; every `other` area code is hand-reviewed.
- Stage 1 trial: `data/seeds/aau_members_2026-10-03_TRIAL.csv` (71 members) and `data/seeds/institutions_seed.csv` (faculty URL and `url_status` for all 71). 67 institutions have sociology departments; Caltech, CMU, MIT and Rochester do not.
- Extraction prompt `prompts/extraction/extract_v1.md` (draft, not yet used in a production run) with schema `R/extract_schema.R`. Tested on roster pages (Rice, Wisconsin, MSU) and profile pages (Rice, Wisconsin); results and issues in `logs/extract_test_2026-10-05.md`.

**Known issues and per-site handling for stage 2**
- 8 institutions refuse automated access (UC Davis, Michigan, Brandeis, Columbia, Harvard, Johns Hopkins, Princeton, McGill): faculty URLs confirmed by hand; collect lists by hand. Do not work around blocks.
- MSU: roster loads in `chromote`, but profile pages return a bot-challenge page; collect MSU research areas by hand.
- 8 sites need `chromote` for the roster (ASU, MSU, Texas A&M, Colorado Boulder, UT Austin, Wisconsin, Rice, Toronto); Pitt lists names only (paginated; rank is on profile pages); UC Riverside's roster is an iframe from `profiles.ucr.edu`.
- ASU: the unit (Sanford School of Social and Family Dynamics) has no "sociology" in its name; inclusion under codebook §2 rule 2 is undecided.
- Extraction: pass page text with hyperlinks as `text <url>`; set `max_tokens` to 16000 and split very long listings; use `listing_context` when extracting a profile; rank comes from the roster, areas from the profile.
- Roster recall (missed faculty) has not been checked, and the "profile contradicts listing" rule is untested.

**Next steps**
1. Re-run stage 1 inside the collection window (Oct 15 – Nov 15) and save the dated AAU member list as `data/seeds/aau_members_<date>.csv` (drop `_TRIAL`); confirm `url_verified` dates.
2. Finish the stage 2 scraper (core built and tested on 8 institutions, see `logs/scrape_test_2026-10-09.md`; still to do: scroll/lazy-load handling for UC Riverside, check the remaining ~55 rosters, wire scraper output into extraction with `listing_context`, merge chunk duplicates). Original scope: roster fetch (httr2 or chromote per site), profile fetch, link-preserving text, chunking, §10 conduct (robots.txt, user-agent, 2 s delay, failure log in `logs/`).
3. Build the `person_id` registry code and `people`/`snapshots` assembly (derive `included` in code from rank, appointment type, and flags).
4. Draft the ASA coding prompt `prompts/coding/code_v1.md` (stage 4; Opus 5.5; separate from extraction).
5. Freeze `extract_v1.md` at the first production run; any later change is a new version plus a §8 entry.
6. First-year validation sample (~50 people) per codebook §7.
