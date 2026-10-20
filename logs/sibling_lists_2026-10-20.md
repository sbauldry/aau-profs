# Sibling lists, 2026-10-20

- Discovery: `R/22_discover_sibling_lists.R` over 58 faculty pages (44 institutions with candidates, 128 raw candidates); curated by hand to `data/seeds/institution_pages.csv` (77 pages, 38 institutions: emeriti 33, affiliated 28, adjunct 5, nontenure 5, visiting 4, joint 1). Not found: ASU (Visiting Scholars) and UC Riverside (error), Tulane (blocked).
- Extraction: `R/23_extract_sibling_lists.R`, prompt `extract_v1.md`, `claude-sonnet-5-5`; 862 records (emeriti 449, affiliated 293, nontenure 33, visiting 32, adjunct 30, joint 25); about $2.5.
- Tables: 2,825 snapshots (574 faculty-list included, 82 faculty-list undecided, 7 joint-list undecided, the rest excluded). Trial IDs; no production data.
