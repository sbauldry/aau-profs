# Hand-coding the validation sample, 2026

Fill in `handcode_sheet_2026.csv` (50 rows, open it in Excel). Do **not** open `sample_key_2026.csv` until you have finished: it holds the pipeline's answers, and seeing them would bias your coding. Save your finished sheet as `validation/handcode_done_2026.csv` (same columns).

## For each row

Look the person up from `profile_url` (and the department's faculty page if the profile is thin), and fill:

| Column | What to enter |
|---|---|
| `hand_rank` | One of `full`, `associate`, `assistant`, `emeritus`, `nontenure`, `other`, `unknown` (codebook §4.1). Judge from the person's current title on the department page or profile, as the pipeline had to. Bare "Professor" counts as `full` only if the page separates it from Associate and Assistant. |
| `hand_included` | `TRUE` if the person meets codebook §2: a tenured full professor with a primary or formal joint appointment in sociology (administrators and named chairs count; emeriti, courtesy or affiliated, non-tenure-line, visiting, and administrators with no sociology appointment do not). Otherwise `FALSE`. |
| `hand_area_1` to `hand_area_3` | Only if `hand_included` is `TRUE`. Up to three codes from `area_codes_2026.csv`, most prominent first, following codebook §5.1: code from the listed areas (`listed_areas`) and the profile only; substantive areas over methods; `rgc` only for intersectional framing; `teaching` and `public` only as research areas; leave all three blank if the person lists no areas. |
| `hand_notes` | Anything unusual or any case where you were unsure. |

`listed_title` and `listed_areas` are exactly what the automated coder saw. Code areas from them (and the profile if you want to check them), not from what you know about the person.

## Notes

- Use the same codes and spelling as the vocabulary file (lower case, e.g. `rem`, `medical`).
- Do the rank and inclusion columns for all 50 rows, including the ones that look obviously out of scope (about 10 rows are people the pipeline did not include, there to check it in the other direction).
- If a profile page is gone or blocked, put `unknown` for rank, leave inclusion blank, and say so in `hand_notes`.
- Scoring afterwards: `Rscript R/26_score_validation.R` (percent agreement on rank and inclusion; per-section Krippendorff's alpha and percent agreement on the first-listed and any shared code, with the number of cases per section; codebook §7).
