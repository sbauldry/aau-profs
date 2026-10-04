# Stage 1: combine verification passes into data/seeds/institutions_seed.csv
# (institutions fields per codebook.md §3.1, plus url_status for triage).
library(tidyverse)

cand <- read_csv("data/seeds/institutions_seed_candidates.csv", show_col_types = FALSE)
p1 <- read_csv("data/interim/seed_url_check.csv", show_col_types = FALSE)
p2 <- read_csv("data/interim/seed_url_check_pass2.csv", show_col_types = FALSE)

# Latest check per institution: pass 2 supersedes pass 1
chk <- bind_rows(p1 |> anti_join(p2, by = "inst_id"), p2) |>
  select(inst_id, faculty_url = url, status, has_sociology, has_professor, error, checked)

no_dept <- c("caltech", "cmu", "mit", "rochester")  # no sociology department found; confirm by hand
blocked <- c("ucdavis", "umich", "brandeis", "columbia", "harvard", "jhu", "princeton", "mcgill",
             "psu", "umd", "uva")                    # automated access refused or failed (§10: do not work around)

out <- cand |>
  select(inst_id, inst_name, country) |>
  left_join(chk, by = "inst_id") |>
  mutate(
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
      TRUE ~ NA_character_)) |>
  select(inst_id, inst_name, country, has_soc_dept, faculty_url, url_verified, url_status, notes)

write_csv(out, "data/seeds/institutions_seed.csv")
count(out, url_status) |> print()
