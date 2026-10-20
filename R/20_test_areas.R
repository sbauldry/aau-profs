# Test the areas assembly (R/areas.R) with a fake coder (no API calls) on a copy of the trial tables.
# Usage: Rscript R/20_test_areas.R
source("R/areas.R")

tmp <- file.path(tempdir(), "areas_test"); dir.create(tmp)
snap <- read_chr("data/interim/tables_trial/snapshots.csv") |> filter(included == "TRUE") |> slice_head(n = 60)
# make sure the sample has at least 3 empty and one "other" trigger
snap$areas_raw[1:3] <- NA_character_
snap$areas_raw[4] <- "Qqq studies; inequality"
write_csv(snap, file.path(tmp, "snapshots.csv"))

calls <- 0L
fake <- function(recs, sp, batch_label = "b", raw_dir = NULL) {
  calls <<- calls + 1L
  persons <- recs |> transmute(person_id, n_codes = 1L, more_available = FALSE,
                               review_flag = str_detect(areas_raw, "Qqq"), review_note = if_else(str_detect(areas_raw, "Qqq"), "other: qqq", ""),
                               code_model = "fake-model", code_prompt_ver = "v1", tokens_input = 10L, tokens_output = 5L)
  areas <- recs |> transmute(person_id, area_order = 1L, area_code = if_else(str_detect(areas_raw, "Qqq"), "other", "inequality"),
                             matched_text = str_squish(str_sub(areas_raw, 1, 10)), code_model = "fake-model", code_prompt_ver = "v1", hand_coded = FALSE)
  list(persons = persons, areas = areas)
}
quiet <- \(...) suppressMessages(build_areas(...))
sp <- "unused"

r1 <- quiet(tmp, 2026, coder = fake, batch_size = 20, budget_usd = Inf, model = "fake-model", prompt_ver = "v1", sp = sp)
n_has <- sum(!is.na(snap$areas_raw))
stopifnot(nrow(r1$runs) == nrow(snap), nrow(r1$areas) == n_has, calls == ceiling(n_has / 20),   # one run per snapshot; one area row per coded person; batched
          identical(names(r1$areas), areas_cols), identical(names(r1$runs), runs_cols))
stopifnot(all(r1$runs$review_flag[1:3] == TRUE), all(r1$runs$coded_by[r1$runs$n_codes == 0] == "rule"))   # no areas: rule, flagged, no rows
stopifnot(!any(r1$areas$person_id %in% r1$runs$person_id[r1$runs$coded_by == "rule"]))
# coding flags reach snapshots: empty areas and `other` are flagged with a coding note
s1 <- read_csv(file.path(tmp, "snapshots.csv"), show_col_types = FALSE, col_types = cols(.default = "c", year = "i", review_flag = "l"))
stopifnot(all(s1$review_flag[1:3]), str_detect(s1$review_note[1], "coding: no research areas listed"), str_detect(s1$review_note[4], "coding: other: qqq"))
# idempotent: a rerun makes no calls and does not stack notes
c0 <- calls; r2 <- quiet(tmp, 2026, coder = fake, budget_usd = Inf, model = "fake-model", prompt_ver = "v1", sp = sp)
s2 <- read_csv(file.path(tmp, "snapshots.csv"), show_col_types = FALSE, col_types = cols(.default = "c"))
stopifnot(calls == c0, identical(r1$areas, r2$areas), sum(str_count(s2$review_note[4], "coding:")) == 1)
# changed areas_raw is re-coded (one call); unchanged rows are not
s <- read_chr(file.path(tmp, "snapshots.csv")); s$areas_raw[10] <- "Something new"; write_csv(s, file.path(tmp, "snapshots.csv"))
c0 <- calls; r3 <- quiet(tmp, 2026, coder = fake, budget_usd = Inf, model = "fake-model", prompt_ver = "v1", sp = sp)
stopifnot(calls == c0 + 1L, nrow(r3$areas) == nrow(r1$areas), r3$areas$matched_text[r3$areas$person_id == s$person_id[10]] == "Something")
# a hand-coded row is never overwritten, even when areas_raw changes
a <- read_chr(file.path(tmp, "areas.csv")); i <- which(a$person_id == s$person_id[12]); a$area_code[i] <- "theory"; a$hand_coded[i] <- "TRUE"
write_csv(a, file.path(tmp, "areas.csv"))
s$areas_raw[12] <- "Changed after hand coding"; write_csv(s, file.path(tmp, "snapshots.csv"))
r4 <- quiet(tmp, 2026, coder = fake, budget_usd = Inf, model = "fake-model", prompt_ver = "v1", sp = sp)
h <- r4$areas |> filter(person_id == s$person_id[12])
stopifnot(nrow(h) == 1, h$area_code == "theory", h$hand_coded)
# a new prompt version re-codes everyone (comparability: no silent reuse across versions)
c0 <- calls; r5 <- quiet(tmp, 2026, coder = fake, budget_usd = Inf, model = "fake-model", prompt_ver = "v2", sp = sp)
stopifnot(calls > c0)
cat("all areas tests passed\n")
