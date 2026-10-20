# Comparison with the hand-built database ("Head - AAU Database"), 2026-10-20

Names and ranks only (areas later). Ours = trial tables in `data/interim/tables_trial/` (not the production wave).
The hand file has no rank column, so each row is read as a full professor; its Note column marks 3 as emeritus/emerita and 9 as "not soc".
Script: `R/21_compare_head.R`. Files: `hand_vs_ours.csv` (one row per hand row), `ours_only.csv`, `summary_by_inst.csv`, `institutions.csv`, `hand_only_roster_check.csv`.

## Coverage
- 67 universities in the hand file. 57 compared. Not compared: 8 hand-collect sites we cannot scrape (Brandeis, Columbia, Harvard, Johns Hopkins, McGill, Princeton, UC Davis, Michigan), NYU (blocked, no data), MIT (no sociology department).
- Purdue is in our tables but not in the hand file.

## 611 hand rows in the 57 compared institutions
| Outcome | n |
|---|---|
| In both; ours = included full professor | 483 |
| In both; ours undecided (appointment type unknown) | 57 |
| In both; ours excludes | 32 |
| In hand file only (not in our data for that institution) | 39 |

Matching was by first and last name within each institution. 549 matched exactly; 41 more by first initial, spelling variants (22 look like typos in the hand file, e.g. Reuf/Ruef, Skrovetz/Skvoretz, Regenrus/Regnerus), or a different given name.
Ours only: 79 included full professors and 25 undecided with no row in the hand file.

## Where we disagree on rank (32 hand rows we exclude)
- 15 we have as emeritus (the hand Note marks only a few), e.g. Duke's Chaves and Smith-Lovin, UCSD's Goldman and Lampland, UT Austin's Glass and Williams.
- 11 rank unknown: Pitt 7 (profile pages state no rank), Miami 3 ("Professor" with no ranks distinguished on the page), Toronto 1.
- 4 held as courtesy: Schilke (Arizona), Von Hippel (UT Austin) (both marked "not soc" in the hand file), Link and Oselin (UC Riverside; "Professor of Public Policy and Sociology").
- 1 assistant professor (GWU, Kelso); 1 non-tenure (Miami, Portes, "Distinguished Research Professor").

## Hand only (39)
- 7 carry a hand Note (emeritus or not soc).
- 36 of the 39 do not appear in the roster page text we scraped (checked by surname), so the page did not list them or our page capture was incomplete. Examples: Pescosolido (Indiana), Heimer (Iowa), Ghaziani (UCSB), Kalleberg (UNC), Nagel (Kansas), Granfield (Buffalo), Brubaker, Clayman and Kligman (UCLA), Calhoun and 6 others at ASU. These are the recall question to resolve site by site.
- Korzeniewicz (Maryland) is on the page but our extraction kept the surname only; Harris (UNC) matched only inside "Harrison".

## Ours only (79 included)
Toronto 13 (the all-faculty directory includes cross-appointed people), ASU 12 (the Sanford School includes other fields), Georgia Tech 6 (History and Sociology), UCSB 6, and 1 to 3 at 28 other institutions.

## Follow-up: live check of Indiana, Iowa and UCLA (2026-10-20)

All hand-only names at these three departments are on sibling pages of the faculty list that the pipeline never fetched (the seed table holds one URL per institution):

| Institution | Name(s) | Where they are | Hand Note |
|---|---|---|---|
| Indiana | Pescosolido | `/about/emeriti/` (Emeriti Faculty) | none |
| Iowa | Heimer | `/emeritus-faculty` (Professor Emeritus) | none |
| UCLA | Brubaker, Clayman, Kligman | `/people/faculty/emeriti/` | none |
| UCLA | Panofsky | `/people/faculty/joint-faculty/` | not soc |

Each site also has other lists: Indiana "Affiliate Faculty"; Iowa "Visiting", "Adjunct", "Affiliated" and "Emeritus"; UCLA "Joint Faculty" (25 people), "Emeriti" (27), "Academic Administrator & Lecturers", and "All Faculty". The UCLA seed URL redirects to "Core Faculty" only.

What this means:
- The pipeline's Indiana, Iowa and UCLA records are complete for the *current faculty* list, so the "hand only" differences are emeriti, as the user's file includes some emeritus faculty. They are not extraction misses.
- Emeriti and affiliated people are not in our tables at all, although CLAUDE.md and codebook §2 say exclusions are kept with `included = FALSE` so they are auditable. This is a gap between the design and the scraper.
- Joint faculty lists (UCLA) matter for inclusion: codebook §2 includes a formal joint appointment with a budgeted share in sociology, which the page title alone does not establish.

## After scraping the sibling lists (2026-10-20)

Sibling lists (emeriti, affiliated, joint, adjunct, visiting, non-tenure) are now scraped (`R/22_*`, `R/23_*`, `data/seeds/institution_pages.csv`) and kept as excluded records. Rerunning the comparison (611 hand rows, 57 institutions):

| Outcome | n |
|---|---|
| Agree (ours = included full professor) | 483 |
| In both; ours undecided (appointment type unknown) | 57 |
| In both; ours excludes, found on an emeriti list | 17 |
| In both; ours excludes, emeritus by title or heading on the main list | 15 |
| In both; ours excludes, courtesy or affiliated | 9 |
| In both; ours excludes, unknown rank | 11 |
| In both; ours excludes, joint list / other | 3 |
| Hand only | 16 |

Hand-only names fell from 39 to 16. The 16: Guthrie, Powers, Wallace (ASU); Livingston (GWU, not soc); Marquart-Pyatt (MSU, not soc); Fleming (Stony Brook); Schaefer (UC Irvine); Brint, Nieri (UC Riverside, partial roster); Ghaziani (UCSB); Korzeniewicz (Maryland, extracted with surname only); Harris, Yang (UNC); Lakoff (USC); Camacho (Utah); Farrell (Yale, not soc). Still to be checked against the live pages.
