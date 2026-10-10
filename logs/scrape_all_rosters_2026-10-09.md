# Trial scrape of all rosters (no API calls)

- Date: 2026-10-09. Scripts: `R/10_scrape_all_rosters.R` (fetch), `R/11_rebuild_roster_text.R` (rebuild text from saved HTML, no requests). Console log: `logs/scrape_all_rosters_2026-10-09.log`.
- Outputs: `data/interim/scrape_trial/manifest_roster.csv` (one row per page attempted or skipped), `roster_chunks.rds` (roster text per institution). Raw HTML under `data/raw_html/trial/` (git-ignored).
- Result: 71 institutions in config. 58 rosters fetched OK (49 plain HTTP incl. Pitt's 2 pages, 9 chromote); 8 hand (skipped, no request); 4 no department (skipped); 1 blocked (NYU: HTTP 202 bot challenge with empty body, not worked around; config now treats NYU as hand until retried in the window).
- Fixes made during the run: empty or `?challenge=` responses are now treated as blocks; chromote waits until client-side rendering settles (UT Austin went from 2 to 91 professor mentions); script/style/template removed and, when a page has no `<main>`, nav/header/footer/aside removed (text volume down 23%: 711,730 to 547,883 characters; the only dropped "professor" lines were menu links such as "Practice Professors").
- Size: 58 rosters, 547,883 characters (about 137,000 input tokens for one extraction pass); median roster 8,159 characters; two rosters need more than one chunk (Buffalo, UT Austin).
- Needs attention before extraction:
  - Pitt: names only, no ranks on the roster (ranks come from profiles).
  - UC Riverside: only about 9 faculty visible (lazy-loaded cards), profile links missing.
  - Oregon: roster page embeds a campus-wide department menu in `<main>` (13,089 characters, 5 professor mentions); strip it or accept the extra tokens.
  - Toronto: St. George directory lists people with other-campus titles (e.g. UTM); the campus rule needs the review flag.
  - Wisconsin's robots.txt read fine this time (earlier DNS error was transient).
