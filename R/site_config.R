# Per-institution scraping configuration, derived from data/seeds/institutions_seed.csv.
# method: "http" (plain request), "chromote" (headless browser), "hand" (site refuses automated
# access: collect by hand, never work around; codebook.md §10), or "none" (no sociology department).
library(tidyverse)

ucr_embed_url <- paste0(
  "https://profiles.ucr.edu/app/embed?groupId=2220536&profilePictureMode=ifPresent",
  "&viewProfileButtonMode=ifPresent&showAlphaLinks=true&showFilter=true&showTitle=false",
  "&affiliationFilter=All&viewProfilesMode=cards&enableViewModeButton=false",
  "&disableSocialLinks=false&excludeStudentEmployees=false&excludeSecondaryDepartmentEmployees=false")

site_config <- function(seed_file = "data/seeds/institutions_seed.csv") {
  read_csv(seed_file, show_col_types = FALSE) |>
    transmute(
      inst_id, inst_name, roster_url = faculty_url,
      method = case_match(url_status,
                          c("reachable", "reachable_names_only") ~ "http",
                          c("reachable_js_rendered", "reachable_embedded") ~ "chromote",
                          "url_confirmed_by_hand_blocked" ~ "hand",
                          "no_soc_dept" ~ "none"),
      profile_method = if_else(method %in% c("hand", "none"), method, "http"),
      paginate = inst_id == "pitt", max_pages = 20,
      note = notes) |>
    mutate(roster_url = if_else(inst_id == "ucriverside", ucr_embed_url, roster_url),
           profile_method = if_else(inst_id == "msu", "hand", profile_method))
}
