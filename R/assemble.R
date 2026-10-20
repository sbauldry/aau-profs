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

# Units whose name lacks "sociology" but which house sociologists (codebook §2 rule 2 exception, v0.1.22).
# For institutions listed in data/seeds/person_scope.csv, a tenured full professor on the main faculty list is in
# scope only if confirmed as a sociologist: "sociology" counts, "not sociology" excludes, "review" and anyone not
# listed (e.g., a new hire) stay undecided for hand review. Sets scope_status for derive_included().
person_key <- function(x) {
  x <- stringi::stri_trans_general(coalesce(x, ""), "Latin-ASCII")
  after <- stringr::str_squish(stringr::str_remove(x, "^[^,]*,?"))
  # "Name, PhD" / "Name, Jr." drop the suffix; any other comma means "Last, First ..." and is reordered.
  suffix <- !stringr::str_detect(x, ",") | stringr::str_detect(stringr::str_to_lower(after), "^(ph\\.?\\s?d\\.?|jr\\.?|sr\\.?|ii|iii|iv|m\\.?d\\.?|dr\\.?|esq\\.?)\\b")
  x <- if_else(suffix, stringr::str_remove(x, ",.*$"), paste(stringr::str_remove(after, "\\([^)]*\\)"), stringr::str_remove(x, ",.*$")))
  t <- stringr::str_split(stringr::str_squish(stringr::str_to_lower(x)), " ")
  purrr::map_chr(t, \(v) { v <- stringr::str_remove_all(v, "[^a-z]"); v <- v[v != ""]; if (length(v) < 2) NA_character_ else paste(v[1], v[length(v)]) })
}
apply_person_scope <- function(df, file = "data/seeds/person_scope.csv") {
  df$scope_status <- NA_character_
  if (!file.exists(file)) return(df)
  sc <- readr::read_csv(file, show_col_types = FALSE, col_types = readr::cols(.default = "c")) |> mutate(key = person_key(name))
  app <- df$inst_id %in% sc$inst_id & df$rank %in% "full" & coalesce(df$list_type, "faculty") == "faculty"
  hit <- sc[match(paste(df$inst_id, person_key(df$name_raw)), paste(sc$inst_id, sc$key)), ]
  status <- case_when(!app ~ NA_character_, hit$scope %in% "sociology" ~ "ok", hit$scope %in% "not sociology" ~ "excluded", TRUE ~ "undecided")
  note <- case_when(status == "excluded" ~ paste0("outside sociology: ", hit$basis),
                    status == "undecided" & !is.na(hit$basis) ~ paste0("unit has no 'sociology' in its name; sociology appointment to confirm: ", hit$basis),
                    status == "undecided" ~ "unit has no 'sociology' in its name; sociology appointment not yet checked",
                    TRUE ~ NA_character_)
  df$scope_status <- status
  # A confirmed sociologist in the unit settles a dual-unit title: unknown appointment type becomes primary.
  fix <- status %in% "ok" & df$appointment_type %in% "unknown"
  df$appointment_type[fix] <- "primary"
  note[fix] <- paste0("appointment type set to primary: confirmed sociologist in the unit (", hit$basis[fix], ")")
  df$review_note <- if_else(is.na(note), df$review_note, if_else(is.na(df$review_note), note, paste(df$review_note, note, sep = " | ")))
  df
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
    scope_status = if ("scope_status" %in% names(df)) scope_status else NA_character_,
    included = rank == "full" & appointment_type %in% c("primary", "joint") & !on_excl_list & !coalesce(scope_status == "excluded", FALSE),
    review_flag = review_flag | (rank == "full" & appointment_type == "unknown") | coalesce(text_defect, FALSE),
    included = if_else(rank == "full" & appointment_type == "unknown", NA, included),
    review_flag = review_flag | coalesce(scope_status == "undecided", FALSE),
    included = if_else(coalesce(scope_status == "undecided", FALSE) & rank == "full" & !on_excl_list, NA, included)) |>
    select(-emeriti_section, -on_excl_list, -scope_status)
}
