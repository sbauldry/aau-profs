# Coding run over all in-scope trial records, 2026-10-20

- Script: `R/19_build_areas.R` (`R/areas.R`), prompt `prompts/coding/code_v1.md` (draft), model `claude-opus-5-5`
- Input: 528 snapshots with `included = TRUE` in `data/interim/tables_trial/` (trial; IDs are trial IDs)
- Coded by model: 450 (23 batches of up to 20); by rule (no `areas_raw`): 78
- Output: 1,269 area rows; people with 3 codes 389, 2 codes 42, 1 code 18, none 79 (78 by rule, 1 by model)
- Flags: 155 (78 no areas, 18 prose, the rest uncertain or vague); `more_available` set for 295 (more than three codable areas; informational)
- `other` assigned: 0 times
- Cost: about $1.5 for this run (cumulative "code" spend $1.78 including the development trial)
- Not validated: no hand-coded comparison yet (codebook §7).
