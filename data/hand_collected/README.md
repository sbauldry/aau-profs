# Hand-collected faculty pages

For institutions whose sites block automated access (codebook §10), the faculty roster is collected by hand: open the page in your own browser and save its text here. As of 2026-10-21 these are UC Davis, Michigan, Brandeis, Columbia, Harvard, Johns Hopkins and Princeton (retry them first at the production run; NYU and McGill started answering the scraper on 2026-10-21).

## How

1. For each institution, open the faculty roster URL in `data/seeds/institutions_seed.csv` in your own browser.
2. Select all, copy, and paste into a plain-text file named `<inst_id>__<list_type>.txt`, for example `harvard__faculty.txt` or `columbia__emeriti.txt`. Use `faculty` for the main list and the sibling list types in codebook §3.1a (`emeriti`, `affiliated`, `joint`, `adjunct`, `visiting`, `nontenure`) for other lists on the site. Several pages of one list can go in one file, one after another.
3. Put the page URL and the date on the first line, as `# url: <URL>  date: <YYYY-MM-DD>`.
4. Profile links do not survive copying plain text. Where a person's profile matters, add the link after the name if you can, but a roster that shows rank is enough: rank comes from the roster.
5. Rank is what matters most: keep titles ("Professor", "Associate Professor", "Professor Emeritus") and any section headings on the page.

## What the pipeline does with it

The files go through the same extraction prompt and the same `derive_included()` rules as scraped pages (`text <url>` form is optional). A small loader that reads these files in place of `scrape_roster()` is still to be written at the production run; the extraction step needs no change. Hand-collected text is not archived as raw HTML, like everything else (codebook §8, v0.1.5).

Your hand-built database (`data/Head - AAU Database.xlsx`, local only) already has names for these seven institutions but no ranks.
