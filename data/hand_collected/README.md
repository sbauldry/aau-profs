# Hand-collected faculty pages

For institutions whose sites block automated access (codebook §10), the faculty roster is collected by hand: open the page in your own browser and save its text here. As of 2026-10-21 these are UC Davis, Michigan, Brandeis, Columbia, Harvard, Johns Hopkins and Princeton (retry them first at the production run; NYU and McGill started answering the scraper on 2026-10-21).

## How

1. For each institution, open the faculty roster URL in `data/seeds/institutions_seed.csv` in your own browser.
2. Select all, copy, and paste into a plain-text file named `<inst_id>__<list_type>.txt`, for example `harvard__faculty.txt` or `columbia__emeriti.txt`. Use `faculty` for the main list and the sibling list types in codebook §3.1a (`emeriti`, `affiliated`, `joint`, `adjunct`, `visiting`, `nontenure`) for other lists on the site. Several pages of one list can go in one file, one after another.
3. Put the page URL and the date on the first line, as `# url: <URL>  date: <YYYY-MM-DD>`.
4. Profile links do not survive copying plain text. Where a person's profile matters, add the link after the name if you can, but a roster that shows rank is enough: rank comes from the roster.
5. Rank is what matters most: keep titles ("Professor", "Associate Professor", "Professor Emeritus") and any section headings on the page.

## What the pipeline does with it

The files go through the same extraction prompt and the same `derive_included()` rules as scraped pages (`text <url>` form is optional). The loader is `R/28_load_hand_collected.R` (`RUN=production Rscript R/28_load_hand_collected.R`): the main list goes to the roster folder and the sibling lists to the sibling folder, so script 13 and the rest of the pipeline pick them up unchanged. Hand-collected text is not archived as raw HTML, like everything else (codebook §8, v0.1.5).

Your hand-built database (`data/Head - AAU Database.xlsx`, local only) already has names for these seven institutions but no ranks.

## The AAU member list

AAU's "members by year of entry" page blocked our scraper on 2026-10-21, so the dated member list is saved by hand too. Open <https://www.aau.edu/resource-library/aau-member-universities-by-year-of-entry> in your own browser and save it here as `aau_members__<YYYY-MM-DD>.html` (File, Save Page As; the date is the day you saved it), or copy the member lines into `aau_members__<YYYY-MM-DD>.txt` (one university per line with its entry year), or make `aau_members__<YYYY-MM-DD>.csv` with columns `inst_name`, `entry_year` (and optionally `sector`, `country`). Then run `Rscript R/00_build_aau_member_list.R`: it writes `data/seeds/aau_members_<date>.csv` (sector and country carried over from the previous list for known members) and `logs/aau_members_diff_<date>.md` (members added, removed, possible renames, entry-year changes). It stops without writing if the parse looks wrong (fewer than 50 or more than 110 members, missing or duplicate entries). A new member needs a row in `data/seeds/institutions_seed_candidates.csv` and a URL check.

## Single-person additions to a scraped roster

`utoronto__faculty.txt` (2026-10-29) holds one person, Yoonkyung Lee, who is missing from the scraped Toronto directory pages. Its extraction was appended to `data/interim/2026/rosters/utoronto.csv`, not loaded by `R/28`. Do not run `R/28` with `FORCE=1` for Toronto: it would overwrite the full scraped roster with this one record.
