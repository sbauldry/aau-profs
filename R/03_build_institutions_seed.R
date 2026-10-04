# Stage 1: combine verification passes into data/seeds/institutions_seed.csv
# (institutions fields per codebook.md §3.1, plus url_status for triage).
library(tidyverse)

cand <- read_csv("data/seeds/institutions_seed_candidates.csv", show_col_types = FALSE)
p1 <- read_csv("data/interim/seed_url_check.csv", show_col_types = FALSE)
# Later passes supersede earlier ones for the same institution
passes <- map(c("pass2", "pass3", "pass4"),
              \(p) read_csv(str_glue("data/interim/seed_url_check_{p}.csv"), show_col_types = FALSE))
chk <- reduce(passes, \(old, new) bind_rows(anti_join(old, new, by = "inst_id"), new), .init = p1) |>
  select(inst_id, faculty_url = url, status, has_sociology, has_professor, error, checked)

no_dept <- c("caltech", "cmu", "mit", "rochester")  # no sociology department found; confirm by hand
# Automated access refused (HTTP 403) on a correct page (§10: do not work around). The URL
# below comes from web search results and has NOT been fetched.
blocked_urls <- tribble(
  ~inst_id,    ~search_url,
  "ucdavis",   "https://sociology.ucdavis.edu/people/faculty",
  "umich",     "https://lsa.umich.edu/soc/people.directory.html",
  "brandeis",  "https://www.brandeis.edu/sociology/people/index.html",
  "columbia",  "https://sociology.columbia.edu/faculty",
  "harvard",   "https://sociology.fas.harvard.edu/people/faculty",
  "jhu",       "https://soc.jhu.edu/people/",
  "princeton", "https://sociology.princeton.edu/people/faculty",
  "mcgill",    "https://www.mcgill.ca/sociology/contact-us/faculty")
blocked <- blocked_urls$inst_id

out <- cand |>
  select(inst_id, inst_name, country) |>
  left_join(chk, by = "inst_id") |>
  left_join(blocked_urls, by = "inst_id") |>
  mutate(
    faculty_url = coalesce(search_url, faculty_url),
    url_status = case_when(
      inst_id %in% no_dept ~ "no_soc_dept_confirm",
      inst_id %in% blocked ~ "blocked_hand_check",
      status %in% 200 & has_sociology %in% TRUE & has_professor %in% TRUE ~ "reachable",
      status %in% 200 ~ "reachable_check_content",  # 200 but text lacks 'sociolog'/'professor': likely JavaScript-rendered or wrong page
      TRUE ~ "failed_find_url"),
    has_soc_dept = if_else(inst_id %in% no_dept, FALSE, NA),
    url_verified = if_else(url_status == "reachable", checked, as.Date(NA)),
    faculty_url = if_else(inst_id %in% no_dept, NA_character_, faculty_url),
    notes = case_when(
      inst_id == "utoronto" ~ "St. George campus only (codebook §1).",
      inst_id == "asu" ~ "Unit is The Sanford School of Social and Family Dynamics; name lacks 'sociology' (codebook §2 rule 2): decide inclusion.",
      inst_id == "ufl" ~ "Unit is Sociology, Criminology & Law.",
      inst_id %in% blocked ~ "Site returned 403 to automated access; URL from web search, not fetched. Hand check.",
      TRUE ~ NA_character_)) |>
  select(inst_id, inst_name, country, has_soc_dept, faculty_url, url_verified, url_status, notes)

write_csv(out, "data/seeds/institutions_seed.csv")
count(out, url_status) |> print()
