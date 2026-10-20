# Test the person-level scope rule (R/assemble.R: apply_person_scope + derive_included) on synthetic rows.
# Usage: Rscript R/24_test_person_scope.R
suppressMessages(library(tidyverse))
source("R/assemble.R")
f <- tempfile(fileext = ".csv")
write_csv(tribble(~inst_id, ~name, ~scope, ~basis, ~checked,
                  "u1", "Ann Soc", "sociology", "PhD Sociology", "2026-10-20",
                  "u1", "Bob Psych", "not sociology", "no sociology title", "2026-10-20",
                  "u1", "Cy Maybe", "review", "joint with criminology", "2026-10-20"), f)
mk <- \(n, inst = "u1", rank = "full", lt = "faculty") tibble(inst_id = inst, name_raw = n, rank = rank, appointment_type = "primary", list_type = lt,
                                                           review_flag = FALSE, text_defect = FALSE, listing_section = "Faculty", review_note = NA_character_)
d <- bind_rows(mk("Ann Soc"), mk("Bob Psych"), mk("Cy Maybe"), mk("Dee NewHire"), mk("Eve Other", inst = "u2"),
               mk("Bob Psych", rank = "associate"), mk("Gus Soc", lt = "emeriti"), mk("Soc, Ann")) |> apply_person_scope(f) |> derive_included()
inc <- \(n, ...) { r <- filter(d, name_raw == n, ...); stopifnot(nrow(r) == 1); r }
stopifnot(inc("Ann Soc")$included,                                    # confirmed sociologist: in scope
          inc("Bob Psych", rank == "full")$included == FALSE,         # confirmed outside: excluded with a note
          str_detect(inc("Bob Psych", rank == "full")$review_note, "outside sociology"),
          is.na(inc("Cy Maybe")$included), inc("Cy Maybe")$review_flag,   # review: undecided and flagged
          is.na(inc("Dee NewHire")$included), str_detect(inc("Dee NewHire")$review_note, "not yet checked"),   # unlisted: undecided
          inc("Eve Other")$included,                                  # other institutions untouched
          inc("Bob Psych", rank == "associate")$included == FALSE,    # only full professors are affected
          inc("Gus Soc", list_type == "emeriti")$included == FALSE,   # sibling lists untouched by the scope rule
          inc("Soc, Ann")$included,
          person_key("Ann Soc, PhD") == "ann soc", person_key("Korzeniewicz, (Roberto) Patricio") == "patricio korzeniewicz")                             # "Last, First" form matches too
stopifnot(!"scope_status" %in% names(d))
# without the seed file nothing changes
d0 <- mk("Bob Psych") |> apply_person_scope(tempfile()) |> derive_included()
stopifnot(d0$included)
cat("all person-scope tests passed\n")
