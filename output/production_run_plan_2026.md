# Production run plan, 2026 (first collection year)

Drafted 2026-10-21; decisions recorded 2026-10-21. Collection window: Oct 15 – Nov 15, 2026. Status: plan approved; Phase 0 (preparation) built and tested 2026-10-21; nothing has been run for production.

## Goal

Produce the first real `people`, `snapshots` and `areas` tables in `data/final/` (with a fresh `person_id_registry.csv`), from a dated AAU member list, frozen prompts and pinned models, plus a validated sample. Everything so far is trial output under `data/interim/*_trial` and must not leak into `data/final/`.

## What the trial tells us (basis for the estimates)

- Scope: 71 AAU members; 67 have a sociology department; 58 rosters fetched by the scraper in the trial, plus NYU and McGill since 2026-10-21 (60). Seven are still blocked: UC Davis, Michigan, Brandeis, Columbia, Harvard, Johns Hopkins, Princeton.
- Trial output: 2,868 people and snapshots; 586 in scope (`included = TRUE`); about 90 undecided; 5 records with no name.
- API spend for the whole trial, all steps: **$12.79** (931 Sonnet 5.5 extraction calls $10.9, 31 Opus 5.5 coding calls $1.9). The earlier $30–40 estimate was too high. Expect **$13–16** for the production run (same scope, plus NYU, McGill and the hand-collected sites). Set a hard budget cap of $25.
- Time: rosters about 15 min and sibling lists about 10 min of polite fetching (2 s between requests); profiles about 20 min of fetching; extraction and coding calls add roughly 1–2 hours. The whole machine run fits in one working day.
- The hand-built database comparison (59 institutions) found no unexplained gaps except one name (NYU's DiMaggio); recall looks good.

## Decisions (recorded 2026-10-21)

1. **Freeze `extract_v1.md` and `code_v1.md` as they are: yes.** They are frozen at the first production API call (Phase 2, step 1), not before: the headers change to `status: FROZEN` with the date and SHA-256 recorded in `logs/prompt_freeze_2026.md`, and a codebook §8 entry (v0.1.25) is logged then. Known small defects (empty name parts for multi-part or "Last, First" names; unknown rank where a roster does not distinguish "Professor") stay with code and hand review, not prompt edits.
2. **Budget cap: $25** for the production run (expected $13–16).
3. **Machine run start date: Oct 27, 2026.**
4. **The seven blocked sites (UC Davis, Michigan, Brandeis, Columbia, Harvard, Johns Hopkins, Princeton) are hand-collected right after the machine run**, by the project owner, so the roster texts go through extraction in one batch.
5. **Production registry:** a fresh `data/final/person_id_registry.csv` starting at `p000001`; trial files stay under `data/interim` and are labeled.

## Phase 0: preparation (about one day, no API calls)

Code changes, each with a test where there is logic:

1. **One run setting** (`RUN=trial|production`, a small `R/run_config.R`) that sets the paths and year for every stage, replacing the hard-coded trial paths in scripts 10, 11, 12, 13, 14, 16, 19, 22, 23, 25 and `site_config`/`build_tables`. Production: `data/raw_html/2026/`, `data/interim/2026/{scrape,rosters,siblings,profiles}/`, tables in `data/final/`. Trial stays untouched for comparison.
2. **Prompt freeze guard:** `load_system_prompt()` refuses to run in production unless the prompt header says `status: FROZEN` and its SHA-256 matches the one recorded in `logs/prompt_freeze_2026.md`. Freezing = edit the header (status, date) and record the hash; any later edit fails the guard until a new version file is created (codebook §9).
3. **Run record:** each stage writes a line to `logs/run_2026.md` (date, stage, model ID, prompt version, counts, cost) as the conventions require.
4. **Hand-collected loader** (`R/28_load_hand_collected.R`): reads `data/hand_collected/<inst_id>__<list_type>.txt` and feeds the same extraction and `derive_included()` rules (the README is in place).
5. **Roster-to-extraction in one script:** merge the scrape and extract steps of 10–12 so a rerun resumes per institution (the profile and sibling steps already do).
6. **Checks that fail loudly:** production refuses to write if `data/final/` contains an ID that is not in its registry, if `RUN=trial` outputs are being read, or if the budget cap is passed.

### Phase 0 status (built and tested 2026-10-21)

| Item | Where | Test |
|---|---|---|
| Run setting `RUN=trial|production`, folders, year, budget cap, separate production usage log | `R/run_config.R`; wired into scripts 10–14, 16, 19, 21–23, 25, 28, 30 | `R/29_test_run_infrastructure.R` |
| Prompt freeze guard (`freeze_prompt()`, `assert_prompt_frozen()`, called by `load_system_prompt()` in production) | `R/freeze.R`, `R/extract.R` | same; the real prompts are still DRAFT (not frozen) |
| Run record `logs/run_<year>.md` | `run_log()` in `R/run_config.R`, called by the stage scripts | same |
| Hand-collected loader | `R/hand_collected.R`, `R/28_load_hand_collected.R` | same (fake extractor) |
| Roster driver: scrape then extract per institution, resumable, budget-capped | `R/30_run_rosters.R` | dry run only (it needs the frozen prompt and the API) |
| Fail-loudly checks: trial/production path separation, `data/final` never written by a trial, table integrity after every build (registry sequential, IDs in registry, snapshot key unique) | `assert_run_safe()`, `check_tables_integrity()` | same |

Dry run in a scratch root (`AAU_RUN_ROOT`): production table build gave a fresh registry from `p000001`, passed the integrity check, and left all trial files byte-identical; the unfrozen prompt was refused by the prompt loader, the roster driver and the hand loader. Regression: the trial tables rebuilt byte-identical after the rewiring, and all earlier tests pass.

## Run-day checklist (Oct 27)

Environment: `export RUN=production` (everything below reads and writes production folders and logs). One copy of a script at a time.

1. Phase 1 (stage 1 refresh): save AAU's members page by hand (it blocks the scraper) as `data/hand_collected/aau_members__<date>.html` and run `Rscript R/00_build_aau_member_list.R` to write `data/seeds/aau_members_<date>.csv` and the diff log; re-run `R/01_verify_seed_urls.R` (and passes as needed) and update `institutions_seed.csv`; retry the seven blocked sites once; `Rscript R/22_discover_sibling_lists.R`, review only the differences from `institution_pages.csv`.
2. Freeze the prompts (once, before any production API call):
   `Rscript -e 'source("R/freeze.R"); freeze_prompt("prompts/extraction/extract_v1.md","claude-sonnet-5-5","0.1.25"); freeze_prompt("prompts/coding/code_v1.md","claude-opus-5-5","0.1.25")'`
   then add the codebook §8 entry (v0.1.25) and commit.
3. `Rscript R/30_run_rosters.R` (rosters), then `Rscript R/23_extract_sibling_lists.R`, then `INST=all Rscript R/13_extract_profiles.R`.
4. `Rscript R/14_build_tables.R`, then `Rscript R/19_build_areas.R`.
5. Acceptance checks (below); `git add -A && git commit`, push.
6. After hand collection: place files in `data/hand_collected/`, `Rscript R/28_load_hand_collected.R`, then repeat steps 3 (profiles only) and 4.
7. Redraw the validation sample: `Rscript R/25_validation_sample.R`.

## Phase 1: stage 1 refresh (about half a day)

1. Save AAU's members page by hand (its page blocks automated access) and build the dated list with `R/00_build_aau_member_list.R` (drops `_TRIAL`; diffs against the trial list and logs any change in membership).
2. Re-verify all 71 URLs (`R/01`), retry the seven blocked sites once each (polite; blocks are not worked around), and update `institutions_seed.csv`.
3. Rediscover sibling lists (`R/22`) for all institutions including NYU and McGill; review only the differences from `institution_pages.csv`.
4. Re-confirm the person-level scope list for ASU (`person_scope.csv`).

## Phase 2: machine run (one day, in this order)

1. Freeze both prompts (decision 1); the guard is now active. Log the freeze in codebook §8 (v0.1.25) and `logs/prompt_freeze_2026.md`.
2. Scrape and extract rosters (all reachable institutions), then sibling lists, then profile pages for full and unknown-rank people. One copy at a time (the earlier double run double-billed).
3. Build tables into `data/final/` (`R/14`), code areas (`R/19`), build the review queue.
4. Acceptance checks before moving on (below).

## Phase 3: hand collection and review (several days, your time)

1. Collect the seven blocked rosters by hand (about 20 minutes each; README in `data/hand_collected/`), plus MSU, Toronto and Tulane profile data where needed; I run the loader and rebuild.
2. Hand review the queue: undecided appointment types, unknown ranks, the five unnamed records, flags from coding. In the trial this was about 235 flagged records, many of them cheap (no areas, prose). Estimated 3–5 hours.

## Phase 4: validation (your time, about half a day)

Redraw the 50-person sample from the production tables (`R/25`), hand-code the blind sheet (instructions in `validation/`), score with `R/26`. Report agreement in `validation/results_2026.md`. If agreement is low on some stratum, decide whether that is a prompt problem (new version for 2027, logged) or a data problem.

## Phase 5: close out

Update CLAUDE.md and codebook status; commit `data/final/`; tag the release (`v2026.0`); push. No raw HTML is archived (§8, v0.1.5). Back up `data/final/person_id_registry.csv` separately: it is the one file that cannot be rebuilt.

## Acceptance checks (go/no-go before hand review)

- Per-institution counts of roster records and in-scope people are within about 10% of the trial, or the difference is explained (new hire, departure).
- Re-run the hand-database comparison: 'hand only' and 'ours only' differences all explainable.
- Zero extraction calls lost to `max_tokens`; the block and failure manifest is complete (every institution is in the data, flagged, or listed as hand-collect).
- All tests pass (registry, changes, areas, person scope, validation).
- `data/final/` has no trial IDs; the registry is sequential and has no gaps or duplicates.
- Cost within the cap; the run record is complete.

## Risks and mitigations

- **A site changes layout or starts blocking:** the manifest records it; the institution falls to hand collection. Do not retry in a storm.
- **Interrupted run:** every stage resumes from per-page caches.
- **Prompt change after the freeze:** blocked by the guard; changes are a new version.
- **Mid-window membership or faculty changes:** the run date is recorded as the collection date; the next year's `changes` table handles the rest.
- **Cost surprise:** hard cap; per-call token log; Batch API would halve cost but is not worth the complexity at this size.

## Schedule (updated for the Oct 27 start)

| Dates | Work |
|---|---|
| Oct 22–26 | Phase 0 (code, tests, dry runs on trial data) |
| Oct 27–28 | Phase 1 and 2 (stage 1 refresh, prompt freeze, machine run, acceptance checks) |
| Oct 29–Nov 5 | Phase 3 (hand collection of the seven sites, hand review) |
| Nov 6–10 | Phase 4 (redraw and hand-code the validation sample, score) |
| Nov 11–15 | Buffer, Phase 5 close-out |
