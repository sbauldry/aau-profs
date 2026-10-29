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
      paginate = case_match(inst_id, "pitt" ~ "next", "uchicago" ~ "pages",
                            "uoregon" ~ "letters", .default = NA_character_),
      max_pages = 30,
      note = notes) |>
    mutate(roster_url = case_when(inst_id == "ucriverside" ~ ucr_embed_url,
                                  # Toronto: one request for the whole list. Paging by last name alone reordered tied surnames between
                                  # requests and dropped Yoonkyung Lee in the 2026 production scrape (107 listed, 106 captured).
                                  inst_id == "utoronto" ~ str_c(roster_url, "?sort_by=ppl_last_name_value&items_per_page=200"),
                                  .default = roster_url),
           # Toronto profile pages return a JS challenge and Tulane's are blocked (2026-10-20): not worked around;
           # rank and areas come from the roster alone and the rest goes to hand review.
           profile_method = if_else(inst_id %in% c("msu", "utoronto", "tulane"), "hand", profile_method))
}
