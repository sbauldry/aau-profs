# End-to-end test: Duke (development, not a collection run)

- Date: 2026-10-09. Script: `R/09_end_to_end_test.R`; helpers `R/extract.R`, `R/assemble.R`.
- Model `claude-sonnet-5-5`, prompt `extract_v1` (draft). Pipeline: scrape roster (http) -> extract (1 chunk) -> scrape 6 profiles -> extract with `listing_context` -> merge -> derive `included` in code.
- Outputs: `data/interim/e2e_test/duke_roster.csv` (44 records), `duke_profiles.csv` (6), `duke_merged.csv` (44).
- Roster rank counts: full 27, associate 3, assistant 6, emeritus 2, nontenure 2, other 4.
- Recall check: the roster text has 47 unique person links; 44 became records; the 3 others are staff (program coordinator, business manager). No faculty missed.
- Inclusion (derived in code): 14 full + primary => included; 2 full + courtesy => excluded; 11 full with unknown appointment type => `included = NA`, review flagged.
- Finding: Duke's faculty page mixes sociology faculty with people whose home is another unit (Cultural Anthropology, Public Policy, Business, Law, Political Science), with no section headings. The model labelled these `unknown` (title names another unit only). Of 6 profiles fetched, 2 resolved to `courtesy` (profile says "secondary appointment in sociology"); 4 stayed `unknown` (profile text does not state the nature of the sociology appointment).
- Research areas: 1 of 6 profiles had a labeled list (scholars.duke.edu profiles often have prose only).
- No text defects; model ID and prompt version recorded on every row.
