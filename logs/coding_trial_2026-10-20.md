# Coding prompt development trial, 2026-10-20

- Script: `R/18_test_coding.R` (prompt `prompts/coding/code_v1.md`, draft; model `claude-opus-5-5`)
- Sample: 30 included trial records, seed 20261020 (3 empty `areas_raw`, 7 prose, 20 short lists)
- Runs: first run flagged 19 of 30 for review (rule 12 over-flagged the three-code limit); rule 12 was revised and the sample rerun.
- Final run: 30 people, 27 coded, 9 flagged (3 no areas, 5 prose, 1 alternative section). Outputs in `data/interim/coding_trial/`.
- Cost: about $0.30 across 5 Opus calls including one call lost to a parser bug (raw output is now saved before parsing). Roughly $0.12 per 30 people, so about $2 for 528 people.
- Not validated: no hand coding yet; codes were read through for plausibility only (codebook §7 requires the hand-coded sample for agreement).
