# AAU Sociology Full Professors: Schema and Codebook

Version 0.1.12 (draft), October 2026

## 1. Purpose and scope

An annual panel of full professors of sociology at member institutions of the Association of American Universities (AAU). Each annual collection records who holds the rank of full professor in each sociology department, their appointment details, and their research areas.

**Reference date.** Each year reflects department websites as retrieved during a fixed collection window (target: October 15 – November 15). Record the actual retrieval date for every page.

**Institutional frame.** AAU membership as of the year's reference date. Record membership changes in `institutions`. **Source:** AAU's official member list, "AAU Member Universities By Year of Entry" (https://www.aau.edu/resource-library/aau-member-universities-by-year-of-entry), linked from https://www.aau.edu/about/member-universities. The list page carries a publication date; check it against the count stated on the members page (currently 69 US and 2 Canadian). Each year, save a dated copy of the list (e.g., `data/seeds/aau_members_2026-10-15.csv`, with the retrieval date in the file name and the page URL recorded) and build `institutions` from it. Canadian members (currently the University of Toronto and McGill University) are included; set `country` to `CA`.

**Campus restriction.** Multi-campus institutions are restricted to a single campus. For the University of Toronto (`utoronto`), include only the St. George campus; exclude the Mississauga and Scarborough campuses, even though they have sociology units. Record the campus restriction in `institutions.notes`. If a person is listed at St. George and at another campus, include them only if they hold a tenured full professor appointment at St. George, and set `review_flag`.

## 2. Unit of observation and inclusion rules

**Unit:** a person × year × institution.

**Scope.** Tenured full professors only. Tenure is inferred from rank on a tenure line: a title of Professor (including named or distinguished professorships) on the tenure track counts as tenured, since department pages rarely state tenure status. Non-tenure-line professor titles are excluded (at Canadian institutions, e.g., "Professor, teaching stream"; "tenure-stream" is the equivalent of tenure-line).

**Include** a person in a year if all of the following hold:
1. The department's official faculty listing or the person's university profile lists them as Professor or as a named or distinguished Professor. "Professor" with no qualifier counts as full professor only when the department's listing distinguishes it from Associate and Assistant Professor.
2. The appointment is tenure-line and in a sociology department (at a multi-campus institution, on the designated campus; see §1). A department that combines sociology with another field (e.g., "Sociology and Criminology") counts if sociology is in its name.
3. The appointment is primary or a formal joint appointment (a budgeted share in sociology). A sociology faculty member who also holds a joint appointment in another department or unit is included (record the other units in `joint_units`).
4. Administrative roles do not affect inclusion. Department heads and chairs, deans, and other administrators are included if they hold a tenured full professor appointment in sociology (record the role in `admin_role`).

**Exclude, but retain in `snapshots` with `included = FALSE`:**
- Emeritus or emerita, including research professors emeriti
- Courtesy, affiliated, adjunct, or "by courtesy" appointments
- Clinical, teaching, research, and practice professor tracks (non-tenure-line)
- Visiting professors
- Administrators with no sociology faculty appointment, such as a dean listed only in an administrative role

**Edge cases to flag** (`review_flag = TRUE`):
- A department lists someone as faculty but the university profile gives a different rank
- The person appears on the faculty page but no rank is stated anywhere
- Joint appointments where the sociology share is unclear
- A person also listed as full professor at a second AAU institution

## 3. Tables

### 3.1 `institutions`

One row per institution per year.

| Field | Type | Description |
|---|---|---|
| `inst_id` | chr | Stable short code, e.g., `purdue`, `umich` |
| `inst_name` | chr | Official name |
| `year` | int | Year of collection |
| `aau_member` | lgl | AAU member as of the reference date |
| `country` | chr | `US` or `CA` |
| `has_soc_dept` | lgl | Has a sociology department, or a combined department meeting rule 2 above |
| `dept_name` | chr | Department name as listed |
| `faculty_url` | chr | Seed URL for the faculty directory |
| `url_verified` | date | Date the seed URL was confirmed to work |
| `notes` | chr | Free text |

### 3.2 `people`

One row per person, stable across years.

| Field | Type | Description |
|---|---|---|
| `person_id` | chr | Stable ID, e.g., `p000123`; never reused |
| `name_last` | chr | Last name |
| `name_first` | chr | First name |
| `name_middle` | chr | Middle name or initial, if listed |
| `name_variants` | chr | Semicolon-separated alternate forms seen across years |
| `orcid` | chr | ORCID iD, if available; primary key for matching |
| `phd_inst` | chr | PhD-granting institution |
| `phd_year` | int | Year of PhD |
| `first_year` | int | First year observed |

### 3.2a `person_id` registry

`person_id` values are minted only from a registry file, `data/final/person_id_registry.csv`, which is version-controlled.

- **Format:** `p` plus six digits (e.g., `p000123`), assigned sequentially from `p000001`. The next ID is the maximum ever issued plus one, counting retired IDs.
- **Fields:** `person_id`, `minted_year`, `status` (`active` or `retired`), `merged_into` (the surviving `person_id`, if retired by a merge), `note`.
- **Rules:** an ID, once minted, is never reused or reassigned. A confirmed merge (see §6) marks one ID `retired` with `merged_into` set; it is never deleted. Only the registry code mints IDs, and it writes to the registry before any table uses the new ID.

### 3.3 `snapshots`

One row per person × year × institution. This is the analytic core.

| Field | Type | Description |
|---|---|---|
| `person_id` | chr | FK to `people` |
| `year` | int | Year of collection |
| `inst_id` | chr | FK to `institutions` |
| `rank` | factor | See §4.1 |
| `title_raw` | chr | Full title exactly as listed |
| `named_chair` | lgl | Holds a named or endowed professorship |
| `distinguished` | lgl | Holds a university-level distinguished title |
| `appointment_type` | factor | See §4.2 |
| `joint_units` | chr | Other units, semicolon-separated |
| `admin_role` | chr | Current administrative role, e.g., Department Head |
| `areas_raw` | chr | Research areas exactly as listed on the profile |
| `included` | lgl | Meets the inclusion rules in §2 |
| `review_flag` | lgl | Needs hand review |
| `review_note` | chr | Reason for the flag or the resolution |
| `profile_url` | chr | URL of the individual profile |
| `retrieved` | date | Date the page was retrieved |
| `html_file` | chr | Path to the cached HTML (local working copy only; cached pages are not archived or version-controlled, so the file may not exist on another machine) |
| `extract_model` | chr | Model string used for extraction |
| `extract_prompt_ver` | chr | Version of the extraction prompt |

### 3.4 `areas`

Long format, with one row per person × year × institution × coded area.

| Field | Type | Description |
|---|---|---|
| `person_id` | chr | FK |
| `year` | int | FK |
| `inst_id` | chr | FK to `institutions` |
| `area_code` | chr | See §5 |
| `area_order` | int | 1 = most prominent as listed; maximum 3 |
| `code_model` | chr | Model string used for coding |
| `code_prompt_ver` | chr | Coding prompt version |
| `hand_coded` | lgl | Coded or corrected by hand |

### 3.5 `changes`

Generated each year by comparing it with the prior year. This table drives the hand review.

| Field | Type | Description |
|---|---|---|
| `person_id` | chr | FK |
| `year` | int | Current year |
| `change_type` | factor | `new_full`, `promoted`, `exit`, `moved`, `rank_change`, `title_change`, `name_change` |
| `prior_inst` | chr | Institution in the prior year |
| `current_inst` | chr | Institution in the current year |
| `resolution` | chr | e.g., retired, died, moved to non-AAU, left academia, data error, unknown |
| `verified_by` | chr | Initials |

## 4. Value labels

### 4.1 `rank`

| Code | Meaning |
|---|---|
| `full` | Professor (tenure-line full professor, including named or distinguished titles) |
| `associate` | Associate Professor (retained only to detect promotions) |
| `assistant` | Assistant Professor (retained only to detect promotions) |
| `emeritus` | Professor Emeritus/Emerita |
| `nontenure` | Clinical, teaching, research, or practice professor |
| `other` | Visiting, adjunct, lecturer, other |
| `unknown` | Rank not determinable |

Collecting associate professors is optional. It costs little extra scraping and lets the `promoted` change type be observed directly rather than inferred.

### 4.2 `appointment_type`

| Code | Meaning |
|---|---|
| `primary` | Primary or tenure home in sociology |
| `joint` | Formal joint appointment with a budgeted share in sociology |
| `courtesy` | Courtesy, affiliated, or by-courtesy appointment |
| `unknown` | Cannot be determined |

### 4.3 Missing data

Use `NA` for not applicable or not listed. Do not use `"unknown"` for character fields other than the factors above.

## 5. Research area vocabulary (ASA sections)

Areas are coded to ASA sections. The list below was retrieved October 2026 from ASA's Current Sections page. ASA's sections landing page reports 53 sections and 2 sections-in-formation, while the current-sections page lists 54 plus one section-in-formation. Re-verify each year, and log any additions or renamings in §8.

| Code | ASA Section |
|---|---|
| `aging` | Aging and the Life Course |
| `altruism` | Altruism, Morality, and Social Solidarity |
| `animals` | Animals and Society |
| `asia` | Asia and Asian America |
| `biology` | Biology and Society |
| `children` | Children and Youth |
| `movements` | Collective Behavior and Social Movements |
| `media` | Communication, Information Technologies, and Media Sociology |
| `urban` | Community and Urban Sociology |
| `comphist` | Comparative-Historical Sociology |
| `consumption` | Consumers and Consumption |
| `crime` | Crime, Law, and Deviance |
| `networks` | Decision-Making, Social Networks, and Society |
| `disability` | Disability in Society |
| `drugs` | Drugs and Society |
| `economic` | Economic Sociology |
| `environment` | Environmental Sociology |
| `ethnometh` | Ethnomethodology and Conversation Analysis |
| `family` | Family |
| `global` | Global and Transnational Sociology |
| `mena` | Global Middle East and North Africa |
| `history` | History of Sociology and Social Thought |
| `inequality` | Inequality, Poverty, and Mobility |
| `migration` | International Migration |
| `labor` | Labor and Labor Movements |
| `latinx` | Latina/o Sociology |
| `marxist` | Marxist Sociology |
| `mathematical` | Mathematical Sociology |
| `medical` | Medical Sociology |
| `methods` | Methodology |
| `oow` | Organizations, Occupations, and Work |
| `peace` | Peace, War, and Social Conflict |
| `pews` | Political Economy of the World-System |
| `political` | Political Sociology |
| `rgc` | Race, Gender, and Class |
| `rem` | Racial and Ethnic Minorities |
| `science` | Science, Knowledge, and Technology |
| `socpsych` | Social Psychology |
| `public` | Sociological Practice and Public Sociology |
| `culture` | Sociology of Culture |
| `development` | Sociology of Development |
| `education` | Sociology of Education |
| `emotions` | Sociology of Emotions |
| `humanrights` | Sociology of Human Rights |
| `indigenous` | Sociology of Indigenous Peoples and Native Nations |
| `law` | Sociology of Law |
| `mentalhealth` | Sociology of Mental Health |
| `population` | Sociology of Population |
| `religion` | Sociology of Religion |
| `gender` | Sociology of Sex and Gender |
| `sexualities` | Sociology of Sexualities |
| `body` | Sociology of the Body and Embodiment |
| `teaching` | Teaching and Learning in Sociology |
| `theory` | Theory |
| `other` | No section fits; describe in `review_note` |

The section-in-formation (Creative Sociology) is excluded unless it gains full section status.

### 5.1 Coding rules

1. Code from `areas_raw` and the profile text only, not from publication titles or outside knowledge.
2. Assign one to three codes, ordered by prominence on the profile (first listed = 1).
3. Code substantive areas over methods. Assign `methods` or `mathematical` only when the profile presents methodology as a research area in its own right.
4. When an area maps onto two sections (e.g., "racial inequality in health"), take the more specific substantive one first (`medical`), then the other (`rem`).
5. Apply `rgc` only when the profile frames the work as intersectional. Otherwise use `rem`, `gender`, or `inequality` as appropriate.
6. Use `teaching` and `public` only when these are listed as research areas, not as service or teaching activity.
7. If the profile lists no areas, leave the person uncoded (no rows in `areas`) and set `review_flag`.
8. Whenever `other` is assigned, set `review_flag` and describe the area in `review_note` (in `snapshots`). Every `other` is hand-reviewed. At the yearly vocabulary re-verification, tally `other` notes by theme; a recurring theme prompts a decision on whether the vocabulary needs a change (log it in §8).

Optionally, a crosswalk to coarser groupings (e.g., demography and health; stratification; culture and theory; institutions; methods) can be defined later as a separate table without recoding.

## 6. Identity matching across years

Apply these in order:
1. ORCID match, which is definitive.
2. Same institution plus exact normalized name (lowercased, diacritics stripped, middle names dropped).
3. Same institution plus fuzzy name match (Jaro-Winkler ≥ 0.92) and overlapping `areas_raw`. This is a candidate match only: flag for hand review before linking.
4. Different AAU institution plus exact normalized name plus matching PhD institution and year. This is a candidate move only: do not apply the `moved` label until a reviewer confirms it by hand.
5. Otherwise, a new `person_id`.

Only rules 1 and 2 link records automatically. Rules 3 and 4 produce candidates, which are queued for hand review with `review_flag = TRUE` and a `review_note` naming the candidate `person_id`. Until a reviewer confirms, the record keeps its own `person_id` (no link, no `moved` row in `changes`). On confirmation, the link or `moved` change is recorded by hand with the reviewer's initials and a note. On rejection, the note records the decision so the pair is not re-queued.

Never merge two IDs automatically. Merges are recorded by hand with a note, and a retired ID is never reused.

## 7. Validation

- **First year:** hand-code a stratified random sample of about 50 people (by institution size) on rank, inclusion, and areas. Report agreement with the automated output: percent agreement for rank and inclusion, and Krippendorff's alpha for area codes.
- **Later years:** hand-review all rows in `changes` plus a random 10% of unchanged rows.
- Keep validation results in `validation/` with the year in the file name.

## 8. Change log

This table is the single log of adopted changes that affect comparability across years (inclusion rules, field definitions, vocabulary, prompts, models, ID matching), each with the year it takes effect. Run records (date, model ID, prompt version, input and output counts) go in `logs/`, not here.

| Date | Version | Change |
|---|---|---|
| 2026-10 | 0.1 | Initial draft |
| 2026-10 | 0.1.1 | Renamed `wave` to `year` throughout (`first_wave` to `first_year`); `year` is the collection year. Snapshots and areas keyed by person × year × institution (`inst_id` added to `areas`). Pre-collection harmonization; no data affected. Effective with the first collection year (2026). |
| 2026-10 | 0.1.2 | Inclusion clarified: scope is tenured full professors (tenure inferred from tenure-line Professor rank); administrators and holders of joint appointments with other units are included; administrators with no sociology appointment remain excluded. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.3 | Canadian AAU members included. University of Toronto restricted to the St. George campus. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.4 | Identity matching: rules 3 and 4 now yield candidates only; links and `moved` labels require hand confirmation. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.5 | Raw HTML is not archived. Cached pages are a local working copy, git-ignored and not guaranteed recoverable; `profile_url` and `retrieved` are the audit trail. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.6 | AAU member list sourced from AAU's official members page, with a dated copy saved in `data/seeds/` each year. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.7 | Added the `person_id` registry (§3.2a): sequential `p######` IDs minted from a version-controlled registry; retired IDs are kept and never reused. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.8 | Added prompt versioning rules (§9). Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.9 | Pinned models: Sonnet 5.5 (`claude-sonnet-5-5`) for extraction, Opus 5.5 (`claude-opus-5-5`) for coding. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.10 | §8 designated the single log of comparability-affecting changes; `logs/` holds run records only. Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.11 | Added scraping conduct rules (§10). Pre-collection; effective with the first collection year (2026). |
| 2026-10 | 0.1.12 | Coding rule 8: every `other` code is flagged, described in `review_note`, hand-reviewed, and tallied yearly to inform vocabulary changes. Pre-collection; effective with the first collection year (2026). |

## 9. Prompt versioning and pinned models

- **Location and names:** `prompts/extraction/extract_v1.md`, `prompts/coding/code_v1.md`, then `_v2`, and so on.
- **Header:** each file begins with a short header giving its version string, date created, and one line on what changed from the prior version.
- **Recorded values:** the version string (e.g., `v1`) goes in `extract_prompt_ver` and `code_prompt_ver`, alongside the exact model ID in `extract_model` and `code_model`.
- **Immutability:** a prompt file is never edited after it has been used in a run. Any change, however small, creates a new version file and an entry in §8 stating the year it takes effect. A prompt change can break comparability across years, so flag it before adopting.
- **Separation:** extraction and coding prompts are separate files and separate runs.
- **Pinned models (from 2026):** extraction uses Sonnet 5.5 (`claude-sonnet-5-5`); coding to ASA sections uses Opus 5.5 (`claude-opus-5-5`). Record the exact string in `extract_model` and `code_model` for every run.
- **Changing a model:** a model change for either step can break comparability across years. Flag it before adopting, log it in §8 with the effective year, and consider re-running the prior year with the new model to measure the difference.

## 10. Scraping conduct

- **robots.txt:** check each host's `robots.txt` before fetching and honor it.
- **User-agent:** descriptive and identifying, e.g., `aau-profs-research/1.0 (academic research; contact: <email>)`. The contact address is read from the `SCRAPER_CONTACT` environment variable (set in `~/.Renviron`) and is never written into the repo.
- **Rate:** at least 2 seconds between requests to the same host; one pass per page; no retry storms.
- **Failures:** log fetch failures (403s, dead links, JavaScript-only pages) in `logs/` with the URL and date. A page that cannot be fetched is flagged for hand review; an institution is never dropped silently.
- **Blocks:** if a site blocks automated access, do not work around the block. Flag it and handle that institution by hand.
