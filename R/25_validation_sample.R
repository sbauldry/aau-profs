# Draw the first-year validation sample (codebook.md §7) and write the blind hand-coding sheet.
# Usage: Rscript R/25_validation_sample.R
# Env: TABLES_OUT (default data/interim/tables_trial; production: data/final), TABLES_YEAR (default 2026), SAMPLE_SEED.
# Design (about 50 people):
#   A. 40 people from the in-scope population (included = TRUE, main faculty list), stratified by institution
#      size (terciles of in-scope headcount per institution), allocation proportional to people.
#   B. 10 people from full or unknown rank on a main faculty list who are NOT included (excluded or undecided),
#      to check inclusion decisions in both directions.
# People from the earlier 20-profile spot check are left out so the two checks are independent.
# Outputs in validation/: sample_key_2026.csv (pipeline answers: do not open until coding is finished),
#   handcode_sheet_2026.csv (blind sheet for the coder), area_codes_2026.csv (vocabulary).
library(tidyverse)
source("R/registry.R")   # asa_codes() lives in code_schema.R
source("R/code_schema.R")

out_dir <- Sys.getenv("TABLES_OUT", "data/interim/tables_trial"); yr <- as.integer(Sys.getenv("TABLES_YEAR", "2026"))
seed <- as.integer(Sys.getenv("SAMPLE_SEED", "20261021")); n_a <- 40L; n_b <- 10L
set.seed(seed)

rd <- \(f) read_csv(file.path(out_dir, f), show_col_types = FALSE, col_types = cols(.default = "c"))
snap <- rd("snapshots.csv") |> filter(as.integer(year) == yr, source_list == "faculty") |>
  mutate(included = as.logical(included))
ppl <- rd("people.csv") |> select(person_id, name_first, name_last)
areas <- rd("areas.csv") |> filter(as.integer(year) == yr) |> arrange(person_id, inst_id, as.integer(area_order)) |>
  group_by(person_id, inst_id) |> summarise(model_codes = paste(area_code, collapse = ";"), .groups = "drop")

# institution size = in-scope headcount, split into terciles of institutions
inst_n <- snap |> filter(included %in% TRUE) |> count(inst_id, name = "inst_n") |> mutate(size = case_when(
  ntile(inst_n, 3) == 1 ~ "small", ntile(inst_n, 3) == 2 ~ "medium", TRUE ~ "large"))
snap <- snap |> left_join(inst_n, by = "inst_id")

spot_f <- "validation/profile_spot_check_2026_sample.csv"     # profile URLs of the earlier 20-profile spot check
spot_ids <- if (file.exists(spot_f)) read_csv(spot_f, show_col_types = FALSE)$profile_url else character()

frame_a <- snap |> filter(included %in% TRUE, !profile_url %in% spot_ids)
alloc <- frame_a |> count(size) |> mutate(exact = n / sum(n) * n_a, k = floor(exact), r = exact - k)
alloc$k <- alloc$k + (rank(-alloc$r, ties.method = "first") <= (n_a - sum(alloc$k)))
sample_a <- frame_a |> group_by(size) |> group_split() |> map(\(d) slice_sample(d, n = alloc$k[alloc$size == d$size[[1]]])) |> list_rbind() |>
  mutate(stratum = "A: in scope")
frame_b <- snap |> filter(rank %in% c("full", "unknown"), !(included %in% TRUE), !profile_url %in% spot_ids, !person_id %in% sample_a$person_id)
sample_b <- slice_sample(frame_b, n = n_b) |> mutate(stratum = "B: not included")
s <- bind_rows(sample_a, sample_b) |> left_join(ppl, by = "person_id") |> left_join(areas, by = c("person_id", "inst_id")) |>
  slice_sample(prop = 1) |> mutate(sample_id = sprintf("V%02d", row_number()))

inst_names <- read_csv("data/seeds/institutions_seed.csv", show_col_types = FALSE) |> select(inst_id, inst_name)
s <- left_join(s, inst_names, by = "inst_id")

# key: the pipeline's answers (kept apart from the coder's sheet)
s |> transmute(sample_id, person_id, inst_id, stratum, size, name = paste(name_first, name_last),
               pipeline_rank = rank, pipeline_appointment = appointment_type, pipeline_included = included,
               pipeline_codes = model_codes, pipeline_review_flag = review_flag, areas_raw, title_raw, profile_url) |>
  write_csv("validation/sample_key_2026.csv")
# blind sheet: who to look up, the inputs the model saw, and empty fields to fill
s |> transmute(sample_id, institution = inst_name, name = paste(name_first, name_last), profile_url,
               listed_title = title_raw, listed_areas = areas_raw,
               hand_rank = "", hand_included = "", hand_area_1 = "", hand_area_2 = "", hand_area_3 = "", hand_notes = "") |>
  write_csv("validation/handcode_sheet_2026.csv")
tibble(code = asa_codes(), section = NA_character_) |> mutate(section = {
  cb <- read_file("codebook.md"); sec <- str_extract(cb, "(?s)## 5\\. Research area vocabulary.*?### 5\\.1")
  m <- str_match_all(sec, "(?m)^\\| `(\\w+)` \\| ([^|]+) \\|")[[1]]; m[match(code, m[, 2]), 3] |> str_trim() }) |>
  write_csv("validation/area_codes_2026.csv")

cat("sample:", nrow(s), "| A:", sum(str_starts(s$stratum, "A")), " B:", sum(str_starts(s$stratum, "B")), "\n")
print(count(s, stratum, size)); print(count(s, inst_id, sort = TRUE) |> head(5)); cat("institutions:", n_distinct(s$inst_id), "\n")
cat("with no listed areas:", sum(is.na(s$areas_raw)), "\n")
