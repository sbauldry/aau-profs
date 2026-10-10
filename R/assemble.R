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
  p <- profile |> select(profile_url = source_url, all_of(fields), profile_flag = review_flag,
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
  df |> mutate(
    included = rank == "full" & appointment_type %in% c("primary", "joint"),
    review_flag = review_flag | (rank == "full" & appointment_type == "unknown") | coalesce(text_defect, FALSE),
    included = if_else(rank == "full" & appointment_type == "unknown", NA, included))
}
