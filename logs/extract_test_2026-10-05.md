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
