# Assembly helpers: combine roster and profile extractions; derive inclusion in code.
library(tidyverse)

# Roster chunks overlap, so the same person can appear twice: keep the fuller record.
dedupe_roster <- function(df) {
  df |> mutate(.filled = rowSums(!is.na(pick(everything())))) |>
    arrange(desc(.filled)) |> distinct(name_raw, profile_url, .keep_all = TRUE) |> select(-.filled)
}

# Profile fields override the roster for detail; rank, listing_section, appointment_type stay with
# the roster unless the profile extraction changed them (prompt rule 17 already encodes that).
merge_profile <- function(roster, profile) {
  fields <- c("title_raw", "named_chair", "distinguished", "appointment_type", "rank", "joint_units",
              "admin_role", "areas_raw", "orcid", "phd_inst", "phd_year", "rank_evidence",
              "appointment_evidence", "listing_section")
  # One profile row per URL: a duplicated key would multiply the roster rows in the join.
  p <- profile |> distinct(source_url, .keep_all = TRUE) |>
    select(profile_url = source_url, all_of(fields), profile_flag = review_flag,
           profile_note = review_note, profile_text_defect = text_defect)
  d <- left_join(roster, p, by = "profile_url", suffix = c("", ".p"))
  for (f in fields) d[[f]] <- coalesce(d[[paste0(f, ".p")]], d[[f]])
  d |> select(-ends_with(".p")) |>
    mutate(has_profile = !is.na(profile_flag),
           review_flag = review_flag | coalesce(profile_flag, FALSE),
           text_defect = text_defect | coalesce(profile_text_defect, FALSE))
}

# codebook.md §2: tenured full professor, primary or formal joint appointment in sociology.
# Unknown appointment type on a full professor is not decided here: it is flagged for review.
derive_included <- function(df) {
  if (!"list_type" %in% names(df)) df$list_type <- "faculty"
  df |> mutate(
    # Sibling lists (R/23_extract_sibling_lists.R) are kept so exclusions are auditable. The list a person
    # is on decides what the bare title cannot: emeriti, visiting, non-tenure-line lists are not full
    # professors; affiliated and adjunct lists are courtesy appointments; a joint list does not state
    # a budgeted share in sociology, so appointment type stays undecided (codebook §2).
    list_type = coalesce(list_type, "faculty"),
    on_excl_list = list_type %in% c("emeriti", "affiliated", "adjunct", "visiting", "nontenure"),
    rank = case_when(list_type == "emeriti" & rank %in% c("full", "unknown") ~ "emeritus",
                     list_type == "visiting" & rank %in% c("full", "unknown") ~ "other",
                     list_type == "nontenure" & rank %in% c("full", "unknown") ~ "nontenure",
                     TRUE ~ rank),
    appointment_type = case_when(list_type %in% c("affiliated", "adjunct") ~ "courtesy",
                                 list_type == "joint" & appointment_type != "courtesy" ~ "unknown",
                                 TRUE ~ appointment_type),
    review_note = if_else(list_type == "joint" & rank == "full",
                          paste(na.omit(c(review_note, "on a joint-faculty list: budgeted share in sociology not stated")), collapse = " | "), review_note)) |>
  mutate(
    # A person listed under an emeriti heading is emeritus whatever the bare title says ("Professor").
    emeriti_section = str_detect(coalesce(listing_section, ""), regex("emerit", ignore_case = TRUE)),
    rank = if_else(emeriti_section & rank == "full", "emeritus", rank),
    included = rank == "full" & appointment_type %in% c("primary", "joint") & !on_excl_list,
    review_flag = review_flag | (rank == "full" & appointment_type == "unknown") | coalesce(text_defect, FALSE),
    included = if_else(rank == "full" & appointment_type == "unknown", NA, included)) |>
    select(-emeriti_section, -on_excl_list)
}
