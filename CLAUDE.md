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
- `R/`: pipeline code. Numbered scripts so far: `01_verify_seed_urls.R`, `02_discover_faculty_links.R`, `03_build_institutions_seed.R`, `04_check_js_pages.R` (stage 1); `05_test_extraction.R`, `06_test_profiles.R` (development tests of the extraction prompt); `extract_schema.R` (ellmer schema + `as_extract_tibble()`); stage 2 scraper: `scrape.R` (fetch, robots, rate limit, block detection, link-preserving text, chunking, pagination), `site_config.R` (per-institution method from the seed table), tests `07_scrape_test.R`, `08_scrape_profiles_test.R`, `09_end_to_end_test.R`, `10_scrape_all_rosters.R`, `11_rebuild_roster_text.R`, `12_extract_all_rosters.R` (trial extraction over every roster), `13_extract_profiles.R` (profile step: fetch and extract profile pages for rank `full`/`unknown`, merge into the roster, derive `included`; `INST=pitt,duke` or `INST=all`; `MAX_PROFILES`, `BUDGET_USD`; resumable via a per-profile cache in `data/interim/profiles_trial/`); `extract.R` (run the extraction prompt on a page), `assemble.R` (dedupe, profile merge, derive `included`; people under an emeriti heading are treated as emeritus)
- `prompts/extraction/`, `prompts/coding/`: versioned LLM prompt files (e.g., `extract_v1.md`)
- `data/seeds/`: dated copies of the AAU member list (from AAU's official members page) and verified faculty-directory URLs
- `data/raw_html/`: cached scraped pages (git-ignored; local only, not archived, not guaranteed recoverable)
- `data/interim/`: intermediate extraction/coding outputs
- `data/final/`: `institutions`, `people`, `snapshots`, `areas`, `changes` tables and `person_id_registry.csv`
- `validation/`: hand-coding and agreement results, year in file name
- `logs/`: run records (date, model ID, prompt version, counts); `api_usage.csv` is the per-call token log written by `R/extract.R` (summarize with `summarize_usage()`); the comparability change log is codebook.md §8
- `output/`: reports and figures
- `renv/`, `renv.lock`: pinned package environment (`renv::restore()` to rebuild)

## Setting up on a new machine

1. Clone the repo and open `aau-profs.Rproj` in RStudio (or start R in the folder). `renv` bootstraps itself; run `renv::restore()` to install the pinned packages.
2. Create `~/.Renviron` (never committed) with two lines, then restart R:
   - `ANTHROPIC_API_KEY=<your key>`
   - `SCRAPER_CONTACT=sgbauldry@gmail.com` (goes in the scraper user-agent; codebook §10)
3. Chrome or Chromium must be installed for `chromote`.
4. `data/raw_html/` is git-ignored and will be empty. Scripts `04`, `05` and `06` read cached pages from it, and `11_rebuild_roster_text.R` rebuilds roster text from the saved HTML of the trial scrape; the scraped text and extraction results themselves are tracked in `data/interim/` (`scrape_trial/roster_chunks.rds`, `extract_trial_all.csv`), so most later steps do not need the HTML. To regenerate pages, rerun `R/04_check_js_pages.R`, `R/06_test_profiles.R` (fetches its own profiles) or `R/10_scrape_all_rosters.R` (about 15 minutes for all rosters).
5. Check that `Sys.getenv("SCRAPER_CONTACT")` and `nzchar(Sys.getenv("ANTHROPIC_API_KEY"))` look right before any scraping or API call.
6. The hand-built comparison database `data/Head - AAU Database.xlsx` is git-ignored and local only; copy it into `data/` to run `R/21_compare_head.R`.

## Status (as of 2026-10-20)

Codebook is at v0.1.22 (draft); the change log in codebook.md §8 records every decision so far. Nothing has been collected for real yet: the collection window is Oct 15 – Nov 15, 2026 (open as of Oct 15). Everything so far is pre-collection setup and trial runs (retrieved dates are Oct 3–20 and are not the production wave).

**Done**
- Project scaffolding, renv, folder structure, GitHub remote.
- Decisions recorded in the codebook: key = person × year × institution; scope = tenured full professors (administrators and joint appointees included); Canadian members included, Toronto = St. George only; fuzzy and cross-institution matches need hand review; raw HTML is not archived; `person_id` registry design; prompt versioning; pinned models (Sonnet 5.5 for extraction, Opus 5.5 for coding); scraping conduct rules; validation scoring; every `other` area code is hand-reviewed.
- Stage 1 trial: `data/seeds/aau_members_2026-10-03_TRIAL.csv` (71 members) and `data/seeds/institutions_seed.csv` (faculty URL and `url_status` for all 71). 67 institutions have sociology departments; Caltech, CMU, MIT and Rochester do not.
- Stage 2 scraper (`R/scrape.R`, `R/site_config.R`): robots.txt, user-agent, 2 s delay, block detection (never worked around), link-preserving text, chunking, pagination (next / numbered pages / A–Z letters), multi-page boilerplate removal. Trial scrape of every roster: 58 fetched OK; 9 institutions are hand-collect (the 8 that refuse automated access plus NYU, which returned an HTTP 202 bot challenge on 2026-10-09); 4 have no department. Logs: `logs/scrape_all_rosters_2026-10-09.md`.
- Stage 3 extraction: prompt `prompts/extraction/extract_v1.md` (draft, not frozen) with `R/extract_schema.R`, `R/extract.R` (per-call token log in `logs/api_usage.csv`), `R/assemble.R`. Tested on rosters, profile pages with `listing_context`, and Duke end to end. Trial extraction over all 58 rosters: 2,029 records, 695 at rank `full`, about $6.81 (`data/interim/extract_trial_all.csv`, `logs/extract_all_rosters_2026-10-09.md`).
- Profile step (trial, 2026-10-20): `R/13_extract_profiles.R` over all 53 institutions with fetchable rosters; 805 extraction calls in total, about $8 cumulative API spend (profile calls cost about a cent each). Results in `data/interim/profiles_trial/<inst>_merged.csv`: 529 full professors `included = TRUE`, 76 full professors undecided (appointment type unknown), 38 full `included = FALSE`, 42 records with rank still unknown. A 20-profile live spot-check found no wrong inclusions among the sample but led to the emeriti-section rule (`validation/profile_spot_check_2026.md`). Pitt, UCSB and Oregon account for most unknown ranks (profiles state no rank). The profile-contradicts-listing rule fired correctly on Pitt.
- Tables (trial, 2026-10-20): `R/14_build_tables.R` mints `person_id`s from a registry and writes `people.csv`, `snapshots.csv`, `review_queue_2026.csv`, `unnamed_review.csv` (4 records with no name, including an Indiana full professor listed only by title). 1,836 people and snapshots; 528 included, 76 undecided. A profile cache bug (truncated URL keys collided at Buffalo, which had 9 identical profiles) was fixed with a URL hash; Buffalo went from 16 to the correct 8 included. Registry tests pass (`R/15_test_registry.R`).
- Hand-database comparison (2026-10-20): `R/21_compare_head.R`, report in `output/head_comparison/REPORT.md`. Of 611 hand rows at 57 compared institutions, 483 agree, 57 are undecided on our side, 32 we exclude, 39 are hand only (36 not on the scraped roster text: a recall check per site is next). The comparison exposed a pipeline gap, fixed: institutions with hand/blocked profiles (Toronto, Tulane, MSU, Miami, UC Riverside) had been dropped from the tables; `13_extract_profiles.R` now writes roster-only merged files for them (Tulane profiles set to hand).
- Sibling lists (2026-10-20): emeriti, affiliated, joint, adjunct, visiting and non-tenure lists were not being scraped (the seed table had one URL per institution), so exclusions were not auditable and the hand-database comparison showed them as missing. `data/seeds/institution_pages.csv` now holds 77 reviewed list pages at 38 institutions; 862 records extracted (about $2.5), all excluded or undecided via `derive_included()`; `snapshots.source_list` added (codebook v0.1.21). After this, hand-only names in the hand-database comparison fell from 39 to 16. Not covered: sibling lists are not paginated and have no profile fetch; institutions with no discovered lists (14) may keep them on the main page.
- Hand-only follow-up (2026-10-20): all 15 hand-database names not in ours are explained and recorded in `data/seeds/head_comparison_resolutions.csv` (read by `R/21_compare_head.R`): outside the department or left (ASU Guthrie, Powers, Wallace; Fleming; Ghaziani), retired or moved (Harris; Claire Yang to Notre Dame; Schaefer to UT Austin, where ours has him), no longer in UCR sociology (Brint, Nieri), deceased (Lakoff), excluded dean (Camacho), and three marked not soc. None is a gap in our data. `build_tables.R` now parses "Last, First" names.
- Setup on this machine: needed `brew install openssl gettext pkg-config`, plus gettext include/lib flags in a user Makevars (via `R_MAKEVARS_USER`) to build `data.table` during `renv::restore()`.
- Cost so far: roughly $7–9 of API spend including the earlier tests. Measured profile call: about 7,300 tokens in, 440 out, $0.02. Estimated first full year: $30–40 (profiles ~$15, Opus coding ~$8); Batch API halves it for non-urgent steps.

**Known issues and per-site handling for stage 2**
- Challenge pages count as blocks (codebook §10, v0.1.16). Toronto profile pages return a JS challenge to plain HTTP (2026-10-20): `profile_method = hand` in `site_config.R`; rank and areas from the roster alone, the 37 unknown-rank people stay flagged. Tulane profiles are blocked (all 6); hand-collect. `looks_blocked()` now recognizes the `leastFactor` challenge marker, so such pages are skipped before any API call.
- No profile links on the roster: UC San Diego (14 of 15 full or unknown-rank people), Miami (all 10), UC Riverside (none). Rank and areas come from the roster or by hand.
- Profile-step caveats: UC Irvine has one external video link (`muse.ai`), skipped. Do not run two copies of `13_extract_profiles.R` at once (double billing).
- 9 institutions are hand-collect: UC Davis, Michigan, Brandeis, Columbia, Harvard, Johns Hopkins, Princeton, McGill (URLs confirmed by hand), and NYU (retry in the window). Do not work around blocks.
- MSU: roster loads in `chromote`, but profile pages return a bot-challenge page; collect MSU research areas by hand.
- `chromote` rosters: ASU, MSU, Texas A&M, Colorado Boulder, UT Austin, Wisconsin, Rice, Toronto. Pitt lists names only (paginated; ranks on profile pages). UC Riverside's roster is an iframe from `profiles.ucr.edu` (the embed URL is in `site_config.R`). It is complete at 9 people: its A-Z filter enables exactly the surname initials of the 9 captured, so it is not lazy-loaded and needs no scrolling (checked 2026-10-20). It has no profile links.
- ASU (decided 2026-10-20, codebook §2 rule 2 exception, v0.1.22): the Sanford School of Social and Family Dynamics has no "sociology" in its name but houses ASU's Sociology MA and PhD, so inclusion is per person from the profile (a sociology title or degree). `data/seeds/person_scope.csv` holds the confirmed decisions; `apply_person_scope()` in `R/assemble.R` applies them before `derive_included()`. Trial result: 5 of 16 full professors included, 9 excluded (developmental psychology and human development), 2 undecided (Paik, Peguero). Anyone not in the file (a new hire) stays undecided.
- Small rosters (UIUC, Missouri, Tufts, GWU) were checked name by name against the live pages on 2026-10-20 and are complete (`validation/small_roster_check_2026.md`).
- Rosters without ranks: Pitt (all 20 unknown), Oregon (21 untitled staff or graduate students on the letter pages), Toronto (37 with no rank; the all-faculty directory also lists cross-appointed people from other units). These need profile pages or hand review.
- Mixed home units (many full professors whose home department is elsewhere, appointment type unknown): Duke, Penn State, Tulane, UVA, GWU. Profile pages resolve some; the rest go to hand review.
- Extraction: pass page text with hyperlinks as `text <url>`; chunk rosters at about 9,000 characters (5,000 if a response hits max_tokens, as at UCSB); use `listing_context` for profile pages; rank comes from the roster, areas from the profile; `included` is derived in code, never by the model. Failed calls that hit max_tokens are billed but not logged.
- Roster recall is checked for Duke, UIUC, Missouri, Tufts and GWU, and against the hand-built database for 57 institutions (`output/head_comparison/REPORT.md`).

**Next steps**
1. Spot-check about 20 profile merges against the live pages (untested at scale: "profile contradicts listing" rule, roster recall); hand-review the 76 undecided and 42 unknown-rank records; hand-collect Tulane, Toronto and the other blocked profiles.
2. Resolve ASU's two undecided people (Paik, Peguero) by hand. The small rosters (UIUC, Missouri, Tufts, GWU) are verified complete, and the ASU scope question is decided.
3. Done in trial: `person_id` registry and `people`/`snapshots` assembly (`R/registry.R`, `R/build_tables.R`; 1,836 trial IDs under `data/interim/tables_trial/`). `changes` builder done and tested (codebook §3.5; the first year has no prior year, so it is empty until 2027). Remaining: `areas` table (after the coding step); hand review of `review_queue_2026.csv` and `unnamed_review.csv`; production run into `data/final` (never reuse trial IDs).
4. Stage 4 trial done end to end: `prompts/coding/code_v1.md` (draft), `R/code_schema.R`, `R/code.R`, `R/areas.R`, `R/19_build_areas.R`. Trial over all 528 in-scope records: 450 coded by Opus 5.5 (about $1.5), 78 with no areas left uncoded by rule; 1,269 area rows, 155 flagged, `other` never assigned (`logs/coding_trial_all_2026-10-20.md`). Remaining: hand-code the validation sample (codebook §7) and compare; freeze at the first production run. Open design point: 78 of 528 included records have no `areas_raw`, since raw HTML is not archived.
5. Re-run stage 1 inside the collection window (Oct 15 – Nov 15; open now): save the dated AAU member list as `data/seeds/aau_members_<date>.csv` (drop `_TRIAL`), recheck URLs and the NYU block, re-scrape, then run the production extraction and profile step. Freeze `extract_v1.md` at that first production run; any later change is a new version plus a §8 entry. The profile script currently reads rosters from `data/interim/extract_trial/` and writes to `profiles_trial/`; point it at production directories first.
6. Hand-collect the 9 blocked institutions (and MSU profiles); first-year validation sample (~50 people) per codebook §7.
