# Extraction test, prompt v1 (development run, not production)

- Date: 2026-10-05
- Model: `claude-sonnet-5-5`
- Prompt: `prompts/extraction/extract_v1.md` (v1, still a draft; header edited after this run to document the schema change)
- Schema: `R/extract_schema.R` (all fields required; empty string = not stated)
- Input: cached pages for rice, wisc, msu (`data/raw_html/*_seedcheck.html`, text only, no link URLs)
- Output: `data/interim/extract_test_v1.csv`, 92 rows (rice 34, wisc 36, msu 22)
- Failed attempts before this run: (1) schema rejected as too complex (too many optional fields); (2) output truncated at default max_tokens (4096). Fixed by making all fields required and setting max_tokens = 16000.

Automated checks: all 92 names and all 92 rank_evidence strings appear verbatim in the page text. `title_raw` is verbatim for 87 of 92; the other 5 (rice) join titles that appear on separate lines with ";".

## Rerun with links and revised rule 7 (same day)

- Prompt change (still v1, draft): dual-unit titles with no stated home department are `unknown` plus `review_flag`; `joint` only when stated. Page text now carries hyperlinks as `text <url>`.
- Output: `data/interim/extract_test_v1_links.csv`, 92 rows (same people as the first run).
- profile_url filled for 92 of 92; no URL shared by two people.
- Rank unchanged for all 92. Appointment type changed for the 8 Wisconsin dual-unit titles (joint/primary -> unknown). Review flags rose from 8 to 12.
- Known over-flag: "John Dewey Professor of Sociology and Social Thought" (Social Thought is a title descriptor, not a unit).

## Profile-page test (same day)

- Script: `R/06_test_profiles.R`. 8 profiles chosen from the roster output (rice 3, wisc 3, msu 2); one GET each, robots.txt checked, 2 s delay.
- MSU: both profile pages returned an Incapsula bot-challenge page (empty body) to plain HTTP. Not worked around (§10); MSU profiles to be collected by hand.
- Output: `data/interim/extract_test_v1_profiles.csv`, 6 rows (rice 3, wisc 3).
- Areas: 5 of 6 profiles gave `areas_raw` (verbatim lists); Gorman's interests are in bio prose, not a labeled list, so none.
- Rank on profile pages: Abramson and Light came back `unknown` because a lone profile page cannot show that "Professor" is distinguished from Associate/Assistant (rule 5). The roster run had both as `full`/ correct section. Decision pending on how to combine roster and profile output.
- Defect: Gorman's `review_note` ends with stray model text (`}]}</think>{`).
