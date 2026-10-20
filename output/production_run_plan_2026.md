# Production run plan, 2026 (first collection year)

Drafted 2026-10-21. Collection window: Oct 15 – Nov 15, 2026. Status: plan only; nothing in it has been run for production.

## Goal

Produce the first real `people`, `snapshots` and `areas` tables in `data/final/` (with a fresh `person_id_registry.csv`), from a dated AAU member list, frozen prompts and pinned models, plus a validated sample. Everything so far is trial output under `data/interim/*_trial` and must not leak into `data/final/`.

## What the trial tells us (basis for the estimates)

- Scope: 71 AAU members; 67 have a sociology department; 58 rosters fetched by the scraper in the trial, plus NYU and McGill since 2026-10-21 (60). Seven are still blocked: UC Davis, Michigan, Brandeis, Columbia, Harvard, Johns Hopkins, Princeton.
- Trial output: 2,868 people and snapshots; 586 in scope (`included = TRUE`); about 90 undecided; 5 records with no name.
- API spend for the whole trial, all steps: **$12.79** (931 Sonnet 5.5 extraction calls $10.9, 31 Opus 5.5 coding calls $1.9). The earlier $30–40 estimate was too high. Expect **$13–16** for the production run (same scope, plus NYU, McGill and the hand-collected sites). Set a hard budget cap of $25.
- Time: rosters about 15 min and sibling lists about 10 min of polite fetching (2 s between requests); profiles about 20 min of fetching; extraction and coding calls add roughly 1–2 hours. The whole machine run fits in one working day.
- The hand-built database comparison (59 institutions) found no unexplained gaps except one name (NYU's DiMaggio); recall looks good.

## Decisions needed from you first

1. **Freeze the prompts as they are?** `extract_v1.md` and `code_v1.md` are drafts. After the first production call any change means a new version and a §8 entry that may break comparability with later years. Known small defects: extraction sometimes leaves name parts empty for multi-part or "Last, First" names (now handled in code, not the prompt); bare "Professor" gives unknown rank at some sites (Miami, Pitt) by design. **Recommendation: freeze both as v1 now** and handle the rest in code and hand review. If you want any prompt wording changed, say so before the freeze; I would re-test on the 30-person coding sample and a few rosters.
2. **Budget cap:** $25 for the run (about 1.6 times the expectation). Recommended.
3. **When to start the machine run:** proposed Oct 25–26, after the preparation below, leaving the rest of the window for hand collection, review and validation.
4. **Hand collection of the seven blocked sites:** you deferred it to this run. Proposed timing: right after the machine run, so the roster texts go through the same extraction in one batch.
5. **Production registry:** a fresh registry in `data/final/` starting at `p000001`. Trial IDs also start there, so the same number can appear in both places; the trial files are labeled and live under `data/interim`. Alternative: start production at a higher number (a codebook change). Recommendation: keep `p000001`.

## Phase 0: preparation (about one day, no API calls)

Code changes, each with a test where there is logic:

1. **One run setting** (`RUN=trial|production`, a small `R/run_config.R`) that sets the paths and year for every stage, replacing the hard-coded trial paths in scripts 10, 11, 12, 13, 14, 16, 19, 22, 23, 25 and `site_config`/`build_tables`. Production: `data/raw_html/2026/`, `data/interim/2026/{scrape,rosters,siblings,profiles}/`, tables in `data/final/`. Trial stays untouched for comparison.
2. **Prompt freeze guard:** `load_system_prompt()` refuses to run in production unless the prompt header says `status: FROZEN` and its SHA-256 matches the one recorded in `logs/prompt_freeze_2026.md`. Freezing = edit the header (status, date) and record the hash; any later edit fails the guard until a new version file is created (codebook §9).
3. **Run record:** each stage writes a line to `logs/run_2026.md` (date, stage, model ID, prompt version, counts, cost) as the conventions require.
4. **Hand-collected loader** (`R/28_load_hand_collected.R`): reads `data/hand_collected/<inst_id>__<list_type>.txt` and feeds the same extraction and `derive_included()` rules (the README is in place).
5. **Roster-to-extraction in one script:** merge the scrape and extract steps of 10–12 so a rerun resumes per institution (the profile and sibling steps already do).
6. **Checks that fail loudly:** production refuses to write if `data/final/` contains an ID that is not in its registry, if `RUN=trial` outputs are being read, or if the budget cap is passed.

## Phase 1: stage 1 refresh (about half a day)

1. Save the dated AAU member list `data/seeds/aau_members_<date>.csv` (drop `_TRIAL`); compare with the trial list and log any change in membership.
2. Re-verify all 71 URLs (`R/01`), retry the seven blocked sites once each (polite; blocks are not worked around), and update `institutions_seed.csv`.
3. Rediscover sibling lists (`R/22`) for all institutions including NYU and McGill; review only the differences from `institution_pages.csv`.
4. Re-confirm the person-level scope list for ASU (`person_scope.csv`).

## Phase 2: machine run (one day, in this order)

1. Freeze both prompts (decision 1); the guard is now active. Log the freeze in codebook §8 (v0.1.24) and `logs/prompt_freeze_2026.md`.
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

## Proposed schedule

| Dates | Work |
|---|---|
| Oct 22–24 | Phase 0 (code, tests), your decisions |
| Oct 25–26 | Phase 1 and 2 (stage 1 refresh, machine run) |
| Oct 27–Nov 3 | Phase 3 (hand collection and review) |
| Nov 4–9 | Phase 4 (validation) |
| Nov 10–15 | Buffer, Phase 5 close-out |
