# Scraper test (development, not a collection run)

- Date: 2026-10-09. Code: `R/scrape.R`, `R/site_config.R`, tests `R/07_scrape_test.R`, `R/08_scrape_profiles_test.R`.
- Roster test institutions: duke (http), rice, wisc, msu (chromote), pitt (http, paginated), ucriverside (chromote, iframe embed URL), harvard (hand: skipped), mit (none: skipped).
- Manifests: `data/interim/scrape_test/manifest_roster.csv`, `manifest_profiles.csv`; roster text in `roster_chunks.rds`. Raw HTML under `data/raw_html/test/` (git-ignored).
- Roster: 7 pages fetched OK for 6 institutions (pitt 2 pages); hand/none institutions skipped without any request. Professor-mention counts for rice and wisc match the earlier cached-page runs (31 each).
- Profiles: 9 of 10 attempted fetched OK (rice 3, wisc 3, duke 3); MSU profile skipped by config (blocked to automated access).
- Fixed during testing: (1) block detection falsely flagged MSU's real page because it embeds the Incapsula script; a challenge marker now counts only on small pages; (2) `method = "none"` institutions were attempted; now skipped.
- Known limits: UC Riverside embed shows only ~9 of the faculty (cards load lazily; scrolling not implemented) and its "View Profile" links carry no URL; Duke profile links point to scholars.duke.edu (a different host from the roster); robots.txt for wisc could not be read once (DNS error) and was treated as allowed, recorded as NA in the manifest on that run (a rerun read it fine).
