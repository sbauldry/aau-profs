# Profile merge spot-check, 2026 (trial run)

Date: 2026-10-20. Data: `data/interim/profiles_trial/*_merged.csv` (extract prompt v1, `claude-sonnet-5-5`; trial, not the production wave).
Method: 20 profiles with a profile extraction (Toronto excluded), seed 20261020, stratified: 5 rank changed by the profile, 4 undecided, 4 courtesy or joint, 7 included primary. Each profile URL was opened in the built-in browser on 2026-10-20 and rank, appointment type, `included` and research areas were compared with the page text. One reviewer; not a substitute for the codebook §7 validation sample.

| # | Inst | Person | Result |
|---|---|---|---|
| 1 | uoregon | Logan Mann | Correct: doctoral student, `other`, excluded |
| 2 | stonybrook | Kathleen Fallon | Correct: Professor, primary, areas match |
| 3 | pitt | Michael R. Glass | Rank correct (Assistant Professor, rank came only from the profile); areas not verifiable in the truncated page text |
| 4 | ucsb | John Baldwin | Correct: Professor, areas match |
| 5 | duke | Sharique Hasan | Correct: Associate Professor of Sociology (current), Professor in Fuqua since 2026; excluded by rank |
| 6 | cornell | Laura Tach | Correct to flag: Professor of Public Policy and Sociology, home department not stated, undecided |
| 7 | uoregon | Richard York | Flag appropriate but likely primary: page lists Environmental Studies and Sociology; undecided |
| 8 | psu | Sarah Damaske | Flag appropriate: titled across several units, undecided; areas not checked against the truncated text |
| 9 | uva | Andrea Press | Flag appropriate: Sociology and Media Studies, undecided; areas NA |
| 10 | ucsb | Paul Amar | Correct: "Affiliated Faculty", Global Studies home, `courtesy`, excluded |
| 11 | uarizona | Regina Deil-Amen | Correct: Dean, College of Education, `courtesy`, excluded |
| 12 | osu | Janet Box-Steffensmeier | Correct: "Professor of Political Science, Courtesy", excluded |
| 13 | umn | Ryan Allen | **Questionable**: set to `courtesy`, excluded, with no review note, but the page lists a Sociology affiliation alongside the Humphrey School title; should be `unknown` and flagged |
| 14 | indiana | Brea Perry | Correct: Professor of Sociology; areas match the extraction |
| 15 | osu | Townsand Price-Spratlen | Correct: Professor, primary, area matches |
| 16 | umn | Penny Edgell | Correct: Professor, Sociology; specialties match |
| 17 | cuboulder | Jillian Turanovic | Correct rank and appointment; `areas_raw` is taken from the biography sentence, not a formal list |
| 18 | ucsb | Waverly Duck | Correct: Professor, named chair, primary |
| 19 | ku | Kelly Chong | Correct: Professor and Chairperson, primary |
| 20 | yale | Grace Kao | Correct: IBM Professor of Sociology, secondary courtesy appointment in ERM, primary in Sociology |

## Summary

- 19 of 20 were correct or appropriately flagged on rank, appointment type and `included`: 15 correct, and 4 undecided (6, 7, 8, 9) that were conservative flags for hand review, not errors.
- 1 questionable call (13, Allen): a unit named in the title was read as the home department and the person was set to `courtesy` with no flag.
- 1 gap: `areas_raw` sometimes comes from biography prose when no research-areas field exists (17); area coding should treat these as weaker evidence.
- Rank taken from a profile when the roster had none worked (3, 5, 6).
- Not tested here: recall of rosters (people missing from a roster page), the 76 undecided records overall, and Toronto, Tulane, MSU and the hand-collect sites.
