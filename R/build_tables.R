# Assemble the `people` and `snapshots` tables (codebook.md §3.2, §3.3) from merged per-institution
# extraction files, minting person_ids through the registry (R/registry.R).
# Idempotent: existing snapshots in `out_dir` (any year, including this one) are the matching
# frame, so a rerun reuses IDs instead of minting new ones.
library(tidyverse)
source("R/registry.R"); source("R/areas.R")

first_tok <- \(x) str_extract(norm_text(coalesce(x, "")), "^[a-z]+")
last_tok  <- \(x) str_extract(norm_text(coalesce(x, "")), "[a-z]+$")

build_tables <- function(in_dir, run_year, out_dir) {
  run_year <- as.integer(run_year)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  registry_file <- file.path(out_dir, "person_id_registry.csv")
  snap_f <- file.path(out_dir, "snapshots.csv"); ppl_f <- file.path(out_dir, "people.csv")

  merged <- list.files(in_dir, pattern = "_merged\\.csv$", full.names = TRUE) |>
    map(\(f) read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"))) |> list_rbind() |>
    mutate(across(c(named_chair, distinguished, review_flag, text_defect, included, has_profile), as.logical),
           phd_year = as.integer(phd_year))

  if (!"list_type" %in% names(merged)) merged$list_type <- NA_character_   # merged files from before sibling lists

  # Name parts: fill what the extractor left empty from name_raw (before the first comma).
  raw1 <- str_remove(coalesce(merged$name_raw, ""), ",.*$")
  cur <- merged |>
    mutate(name_first = coalesce(name_first, first_tok(raw1)),
           name_last = coalesce(name_last, last_tok(raw1)),
           name_key = name_key(name_first, name_last, name_raw),
           year = run_year)

  # Records with no usable name cannot be given an ID: set aside for hand review.
  unnamed <- filter(cur, is.na(name_key))
  write_csv(select(unnamed, inst_id, name_raw, title_raw, rank, source_url, profile_url), file.path(out_dir, "unnamed_review.csv"))
  cur <- filter(cur, !is.na(name_key))

  # One record per person per institution: keep the fuller one, flag that duplicates were merged.
  cur <- cur |> mutate(.filled = rowSums(!is.na(pick(everything())))) |>
    group_by(inst_id, name_key) |> arrange(desc(coalesce(list_type, "faculty") == "faculty"), desc(has_profile), desc(.filled), .by_group = TRUE) |>
    mutate(dup_n = n()) |> slice_head(n = 1) |> ungroup() |> select(-.filled)

  # Same name at more than one institution in one year: possible second AAU appointment, or two people.
  also <- cur |> group_by(name_key) |> filter(n_distinct(inst_id) > 1) |>
    summarise(also_at = list(inst_id), .groups = "drop")
  cur <- cur |> left_join(also, by = "name_key") |>
    mutate(cross_note = map2_chr(also_at, inst_id, \(a, i) if (is.null(a)) NA_character_ else
      paste0("same name also at: ", paste(setdiff(a, i), collapse = ", "), " (second AAU appointment or a different person)"))) |>
    select(-also_at)

  # Matching frame from tables already on disk.
  prior <- if (file.exists(snap_f) && file.exists(ppl_f)) {
    read_csv(snap_f, show_col_types = FALSE, col_types = cols(.default = "c")) |> select(person_id, inst_id, areas_raw) |>
      inner_join(read_csv(ppl_f, show_col_types = FALSE, col_types = cols(.default = "c")) |>
                   select(person_id, orcid, name_first, name_last, phd_inst, phd_year), by = "person_id") |>
      mutate(phd_year = as.integer(phd_year), name_key = name_key(name_first, name_last, NA_character_))
  } else tibble(person_id = character(), inst_id = character(), areas_raw = character(), orcid = character(),
                name_first = character(), name_last = character(), phd_inst = character(), phd_year = integer(),
                name_key = character())

  cur <- assign_person_ids(cur, prior, run_year, registry_file)

  # An ORCID match under a different name is a name change: queue it for `changes` (a file that reruns
  # add to, since a rerun sees the new name as already known) and keep the old form in name_variants.
  prev_names <- prior |> filter(!is.na(name_key)) |> distinct(person_id, .keep_all = TRUE) |>
    transmute(person_id, prior_key = name_key, prior_name = paste(name_first, name_last))
  nc_f <- file.path(out_dir, sprintf("name_changes_%s.csv", run_year))
  name_changes <- cur |> filter(match_rule == "orcid") |> inner_join(prev_names, by = "person_id") |>
    filter(name_key != prior_key) |>
    transmute(person_id, year = run_year, prior_name, current_name = paste(name_first, name_last))
  if (file.exists(nc_f)) name_changes <- bind_rows(read_csv(nc_f, show_col_types = FALSE, col_types = cols(.default = "c", year = "i")), name_changes) |>
    distinct(person_id, year, .keep_all = TRUE)
  write_csv(name_changes, nc_f)
  cur <- left_join(cur, distinct(name_changes, person_id, prior_name), by = "person_id")

  join_notes <- \(...) { x <- na.omit(c(...)); if (length(x)) paste(x, collapse = " | ") else NA_character_ }
  snapshots <- cur |>
    mutate(review_note_all = pmap_chr(list(review_note, profile_note, cand_note, cross_note,
                                           if_else(dup_n > 1, paste(dup_n, "records for this name merged"), NA_character_)), join_notes),
           review_flag = coalesce(review_flag, FALSE) | !is.na(cand_note) | !is.na(cross_note) | dup_n > 1,
           html_file = NA_character_) |>   # raw HTML is a local working copy; no path is recorded in the trial
    transmute(person_id, year, inst_id, rank, title_raw, named_chair, distinguished, appointment_type,
              joint_units, admin_role, areas_raw, listing_section, source_list = coalesce(list_type, "faculty"), rank_evidence, appointment_evidence,
              included, review_flag, review_note = review_note_all, profile_url, retrieved = as.Date(retrieved),
              html_file, extract_model, extract_prompt_ver)

  runs_f <- file.path(out_dir, "coding_runs.csv")
  if (file.exists(runs_f)) snapshots <- apply_coding_flags(snapshots, read_chr(runs_f))

  # people: one row per person, name from this year's record; keep earlier people not seen this year.
  first_or_na <- \(x) if (length(na.omit(x))) first(na.omit(x)) else x[NA_integer_][1]
  new_people <- cur |> group_by(person_id) |>
    summarise(name_last = first(name_last), name_first = first(name_first), name_middle = first(name_middle),
              name_suffix = first(name_suffix),
              name_variants = { v <- setdiff(unique(na.omit(c(name_raw, prior_name))), first(name_raw)); if (length(v)) paste(v, collapse = "; ") else NA_character_ },
              orcid = first_or_na(orcid), phd_inst = first_or_na(phd_inst), phd_year = first_or_na(phd_year),
              .groups = "drop") |>
    mutate(first_year = run_year)
  people <- if (file.exists(ppl_f)) {
    old <- read_csv(ppl_f, show_col_types = FALSE, col_types = cols(.default = "c")) |>
      mutate(phd_year = as.integer(phd_year), first_year = as.integer(first_year))
    bind_rows(new_people |> left_join(select(old, person_id, old_first = first_year, old_var = name_variants), by = "person_id") |>
                mutate(first_year = pmin(first_year, old_first, na.rm = TRUE),
                       name_variants = map2_chr(name_variants, old_var, \(a, b) {
                         v <- unique(na.omit(c(str_split_1(coalesce(a, ""), "; "), str_split_1(coalesce(b, ""), "; ")))); v <- v[v != ""]
                         if (length(v)) paste(v, collapse = "; ") else NA_character_ })) |>
                select(-old_first, -old_var),
              filter(old, !person_id %in% new_people$person_id))
  } else new_people
  people <- people |> select(person_id, name_last, name_first, name_middle, name_suffix, name_variants,
                             orcid, phd_inst, phd_year, first_year) |> arrange(person_id)

  # Snapshots from other years stay; this year's rows are replaced.
  if (file.exists(snap_f)) {
    old_s <- read_csv(snap_f, show_col_types = FALSE, col_types = cols(.default = "c")) |>
      filter(as.integer(year) != run_year) |>
      mutate(across(c(named_chair, distinguished, included, review_flag), as.logical), year = as.integer(year),
             retrieved = as.Date(retrieved))
    snapshots <- bind_rows(old_s, snapshots)
  }
  snapshots <- arrange(snapshots, year, inst_id, person_id)

  write_csv(people, ppl_f); write_csv(snapshots, snap_f)
  snapshots |> filter(review_flag, year == run_year) |>
    select(person_id, inst_id, rank, appointment_type, included, review_note, profile_url) |>
    write_csv(file.path(out_dir, sprintf("review_queue_%s.csv", run_year)))
  invisible(list(people = people, snapshots = snapshots, unnamed = unnamed, assigned = cur))
}
