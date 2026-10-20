# Test the changes builder (R/changes.R) on a small synthetic two-year snapshots table.
# Usage: Rscript R/17_test_changes.R
source("R/changes.R")

s <- \(id, yr, inst, rank, inc, title = "Professor", admin = NA, chair = FALSE)
  tibble(person_id = id, year = yr, inst_id = inst, rank = rank, included = inc, title_raw = title,
         admin_role = admin, named_chair = chair, distinguished = FALSE)
snap <- bind_rows(
  s("A", 2025L, "x", "assistant", FALSE), s("A", 2026L, "x", "full", TRUE),                       # promoted
  s("B", 2026L, "x", "full", TRUE),                                                               # new_full (not listed before)
  s("C", 2025L, "x", "full", TRUE),                                                               # exit (not listed)
  s("D", 2025L, "x", "full", TRUE), s("D", 2026L, "x", "emeritus", FALSE),                        # exit (emeritus)
  s("E", 2025L, "x", "full", TRUE), s("E", 2026L, "y", "full", TRUE),                             # moved
  s("F", 2025L, "x", "full", TRUE), s("F", 2026L, "x", "full", TRUE, "Professor and Chair", "Chair"),  # title_change
  s("G", 2025L, "x", "full", TRUE), s("G", 2026L, "x", "full", TRUE),                             # no change
  s("H", 2025L, "x", "assistant", FALSE), s("H", 2026L, "x", "associate", FALSE),                 # rank_change
  s("I", 2025L, "x", "full", TRUE), s("I", 2026L, "x", "full", NA),                               # unresolved
  s("J", 2025L, "x", "emeritus", FALSE), s("J", 2026L, "x", "full", TRUE),                        # new_full (was emeritus)
  s("K", 2025L, "x", "full", TRUE), s("K", 2026L, "x", "full", TRUE))                             # name_change via input
nc <- tibble(person_id = "K", year = 2026L, prior_name = "Ann Old", current_name = "Ann New")
ex <- tibble(person_id = "D", year = 2026L, change_type = "exit", resolution = "retired", verified_by = "SB")

r <- build_changes(snap, 2026L, 2025L, nc, ex)
ch <- r$changes
got <- \(id, type) ch |> filter(person_id == id, change_type == type)
stopifnot(nrow(got("A", "promoted")) == 1, nrow(got("B", "new_full")) == 1, got("B", "new_full")$detail == "not listed last year",
          nrow(got("C", "exit")) == 1, nrow(got("D", "exit")) == 1, str_detect(got("D", "exit")$detail, "emeritus"),
          nrow(got("E", "moved")) == 1, got("E", "moved")$prior_inst == "x", got("E", "moved")$current_inst == "y",
          nrow(got("F", "title_change")) == 1, nrow(got("H", "rank_change")) == 1,
          nrow(got("J", "new_full")) == 1, str_detect(got("J", "new_full")$detail, "emeritus"),
          nrow(got("K", "name_change")) == 1, str_detect(got("K", "name_change")$detail, "Ann Old"))
stopifnot(!"G" %in% ch$person_id, !"I" %in% ch$person_id, "I" %in% r$unresolved$person_id)    # no change; unresolved set aside
stopifnot(got("D", "exit")$resolution == "retired", got("D", "exit")$verified_by == "SB")         # hand entries survive a rerun
stopifnot(all(ch$change_type %in% change_types), identical(names(ch), names(empty_changes())))
# E moved only because one person_id appears at two institutions; a different person_id would be exit + new_full
stopifnot(nrow(build_changes(snap |> filter(year == 2026L), 2026L, 2025L)$changes) == 0)         # no prior year: empty
cat("all changes tests passed\n")
