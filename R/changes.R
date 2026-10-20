# Build the `changes` table (codebook.md §3.5) by comparing one year of `snapshots` with the prior year.
# Scope for new_full / exit is `included`: TRUE counts as in scope, FALSE as out, and NA (full professor
# whose appointment type is unresolved) is neither, so those people are written to a separate
# "unresolved" table instead of generating changes that may be wrong.
# `moved` needs one person_id at two institutions, which only an ORCID match or a hand-confirmed link
# produces (codebook §6); a candidate move shows up as an `exit` and a `new_full` whose detail says so.
library(tidyverse)

change_types <- c("new_full", "promoted", "exit", "moved", "rank_change", "title_change", "name_change")

empty_changes <- function() tibble(person_id = character(), year = integer(), change_type = character(),
                                   prior_inst = character(), current_inst = character(), resolution = character(),
                                   verified_by = character(), detail = character())

# Person-level summary of one year's snapshots.
year_state <- function(snap) {
  snap |> group_by(person_id) |>
    summarise(inst = paste(sort(unique(inst_id)), collapse = ";"),
              inst_in = paste(sort(unique(inst_id[included %in% TRUE])), collapse = ";"),
              any_in = any(included %in% TRUE), any_unres = any(is.na(included) & rank == "full"),
              rank = { r <- rank[order(match(rank, c("full", "associate", "assistant", "emeritus", "nontenure", "other", "unknown")))]; first(r) },
              title = paste(sort(unique(norm_title(title_raw))), collapse = ";"),
              admin = paste(sort(unique(na.omit(admin_role))), collapse = ";"),
              chair = any(named_chair %in% TRUE) | any(distinguished %in% TRUE),
              .groups = "drop")
}
norm_title <- \(x) str_squish(str_to_lower(str_replace_all(coalesce(x, ""), "[^A-Za-z ]", " ")))

build_changes <- function(snapshots, year, prior_year = year - 1L, name_changes = NULL, existing = NULL) {
  cur <- year_state(filter(snapshots, .data$year == !!year))
  pri <- year_state(filter(snapshots, .data$year == !!prior_year))
  if (nrow(pri) == 0) return(list(changes = empty_changes(), unresolved = tibble()))
  j <- full_join(pri, cur, by = "person_id", suffix = c("_p", "_c"))
  lgl <- \(x) coalesce(x, FALSE)
  j <- j |> mutate(across(c(any_in_p, any_in_c, any_unres_p, any_unres_c), lgl),
                   present_p = !is.na(inst_p), present_c = !is.na(inst_c))

  row <- \(d, type, detail) if (nrow(d) == 0) empty_changes() else
    transmute(d, person_id, year = as.integer(!!year), change_type = type, prior_inst = na_if(inst_p, ""),
              current_inst = na_if(inst_c, ""), resolution = NA_character_, verified_by = NA_character_, detail = detail)

  unresolved <- j |> filter((any_unres_p | any_unres_c) & !(any_in_p & any_in_c)) |>
    transmute(person_id, year = as.integer(year), prior = if_else(present_p, paste0(rank_p, ", in scope ", any_in_p), "not listed"),
              current = if_else(present_c, paste0(rank_c, ", in scope ", any_in_c), "not listed"))
  settled <- j |> filter(!(any_unres_p | any_unres_c))

  gained <- settled |> filter(any_in_c, !any_in_p)
  lost <- settled |> filter(any_in_p, !any_in_c)
  both <- settled |> filter(any_in_p, any_in_c)

  promoted <- gained |> filter(present_p, rank_p %in% c("associate", "assistant"))
  new_full <- gained |> anti_join(promoted, by = "person_id")
  moved <- both |> filter(inst_in_p != inst_in_c)
  title <- both |> anti_join(moved, by = "person_id") |>
    filter(title_p != title_c | admin_p != admin_c | chair_p != chair_c)
  rank_ch <- settled |> filter(present_p, present_c, rank_p != rank_c, rank_p %in% c("full", "associate", "assistant"),
                               rank_c %in% c("full", "associate", "assistant")) |>
    anti_join(promoted, by = "person_id") |> anti_join(lost, by = "person_id")

  ch <- bind_rows(
    row(new_full, "new_full", if_else(new_full$present_p, paste0("listed last year as ", new_full$rank_p), "not listed last year")),
    row(promoted, "promoted", paste0("was ", promoted$rank_p, " last year")),
    row(lost, "exit", if_else(lost$present_c, paste0("listed this year as ", lost$rank_c, ", not in scope"), "not listed this year")),
    row(moved, "moved", "same person_id at a different institution (ORCID match or confirmed link)"),
    row(rank_ch, "rank_change", paste0(rank_ch$rank_p, " to ", rank_ch$rank_c)),
    row(title, "title_change", "title, administrative role, or named/distinguished status changed"))
  if (!is.null(name_changes) && nrow(name_changes) > 0) {
    nc <- name_changes |> filter(year == !!year) |> left_join(select(j, person_id, inst_p, inst_c), by = "person_id")
    ch <- bind_rows(ch, row(nc, "name_change", paste0(nc$prior_name, " to ", nc$current_name)))
  }
  # Keep hand-entered resolutions and initials across reruns.
  if (!is.null(existing) && nrow(existing) > 0)
    ch <- ch |> select(-resolution, -verified_by) |>
      left_join(existing |> select(person_id, year, change_type, resolution, verified_by) |>
                  mutate(year = as.integer(year)), by = c("person_id", "year", "change_type")) |>
      select(all_of(names(empty_changes())))
  list(changes = arrange(ch, change_type, person_id), unresolved = unresolved)
}
