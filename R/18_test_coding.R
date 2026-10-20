# Trial of coding prompt v1 on a stratified sample of included records (development test only).
# Usage: Rscript R/18_test_coding.R   (about 30 people, 2 Opus calls)
library(tidyverse)
source("R/code.R")

set.seed(20261020)
snap <- read_csv("data/interim/tables_trial/snapshots.csv", show_col_types = FALSE, col_types = cols(.default = "c")) |>
  filter(included == "TRUE")
pool <- list(
  empty = filter(snap, is.na(areas_raw)),
  prose = filter(snap, nchar(coalesce(areas_raw, "")) > 300),
  short = filter(snap, nchar(coalesce(areas_raw, "")) <= 300, !is.na(areas_raw)))
samp <- bind_rows(slice_sample(pool$empty, n = 3), slice_sample(pool$prose, n = 7), slice_sample(pool$short, n = 20)) |>
  select(person_id, areas_raw, title_raw, inst_id)
batches <- split(samp, rep(1:2, length.out = nrow(samp)))
sp <- load_system_prompt(code_prompt_file)

res <- imap(batches, \(b, i) code_batch(b, sp, batch_label = paste0("coding_trial_batch_", i), raw_dir = "data/interim/coding_trial/raw"))
persons <- map(res, "persons") |> list_rbind(); areas <- map(res, "areas") |> list_rbind()
dir.create("data/interim/coding_trial", showWarnings = FALSE)
write_csv(persons, "data/interim/coding_trial/persons_v1.csv"); write_csv(areas, "data/interim/coding_trial/areas_v1.csv")

out <- samp |> left_join(persons, by = "person_id") |>
  left_join(areas |> group_by(person_id) |> summarise(codes = paste(area_code, collapse = ", ")), by = "person_id")
write_csv(out, "data/interim/coding_trial/review_v1.csv")
print(summarize_usage() |> filter(step == "code"))
cat("\npeople:", nrow(persons), " coded:", sum(persons$n_codes > 0), " flagged:", sum(persons$review_flag), "\n")
print(count(areas, area_code, sort = TRUE), n = 20)
