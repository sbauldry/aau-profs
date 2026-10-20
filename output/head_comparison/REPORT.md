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
