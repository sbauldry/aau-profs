# Assemble the `areas` table (codebook.md §3.4) from the coding step, and merge coding flags into
# `snapshots`. Areas are coded for in-scope records (`included = TRUE`) only; undecided people are
# coded once their appointment type is resolved.
# Files in `out_dir`:
#   areas.csv         the table (person_id, year, inst_id, area_code, area_order, matched_text, ...)
#   coding_runs.csv   one row per coded snapshot, including people with no codes (the coding record)
# Re-running is cheap and safe:
#   - a snapshot whose `areas_raw` is unchanged (same hash, model and prompt version) is not re-coded;
#   - rows with hand_coded = TRUE are never overwritten (codebook §3.4);
#   - records with no `areas_raw` are handled by rule without an API call (§5.1 rule 7).
library(tidyverse)
source("R/code.R")

areas_hash <- \(x) map_chr(coalesce(x, ""), \(v) digest::digest(v, algo = "md5", serialize = FALSE))
runs_cols <- c("person_id", "year", "inst_id", "areas_hash", "n_codes", "more_available", "review_flag", "review_note",
               "coded_by", "code_model", "code_prompt_ver", "batch_tokens_input", "batch_tokens_output")
areas_cols <- c("person_id", "year", "inst_id", "area_code", "area_order", "matched_text", "code_model", "code_prompt_ver", "hand_coded")

read_chr <- \(f) read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"))
empty_chr <- \(cols) as_tibble(set_names(rep(list(character()), length(cols)), cols))

# Append the coding flag and note to a year's snapshot rows that have a coding run. An earlier
# "coding: ..." note is removed first, so repeated application does not stack notes. (A flag already set
# stays set: to clear one after re-coding, rebuild the year with build_tables, which re-applies this.)
apply_coding_flags <- function(snapshots, runs) {
  if (is.null(runs) || nrow(runs) == 0) return(snapshots)
  r <- runs |> transmute(person_id, year = as.integer(year), inst_id,
                         c_flag = as.logical(review_flag), c_note = if_else(is.na(review_note), NA_character_, paste0("coding: ", review_note)))
  snapshots |> left_join(r, by = c("person_id", "year", "inst_id")) |>
    mutate(review_note = na_if(str_squish(str_remove(review_note, "\\s*(\\|\\s*)?coding: .*$")), ""),
           review_flag = review_flag | coalesce(c_flag, FALSE),
           review_note = pmap_chr(list(review_note, c_note), \(a, b) { x <- na.omit(c(a, b)); if (length(x)) paste(x, collapse = " | ") else NA_character_ })) |>
    select(-c_flag, -c_note)
}

build_areas <- function(out_dir, run_year, coder = code_batch, batch_size = 20, budget_usd = 5,
                        model = code_model, prompt_ver = code_prompt_ver, sp = NULL) {
  run_year <- as.integer(run_year)
  snap_f <- file.path(out_dir, "snapshots.csv"); runs_f <- file.path(out_dir, "coding_runs.csv"); areas_f <- file.path(out_dir, "areas.csv")
  snap <- read_chr(snap_f) |> filter(as.integer(year) == run_year, included == "TRUE") |>
    mutate(key = paste(person_id, inst_id, sep = "|"), areas_hash = areas_hash(areas_raw))
  runs_old <- if (file.exists(runs_f)) read_chr(runs_f) else empty_chr(runs_cols)
  areas_old <- if (file.exists(areas_f)) read_chr(areas_f) else empty_chr(areas_cols)
  rkey <- \(d) paste(d$person_id, d$inst_id, sep = "|")
  protected <- areas_old |> filter(year == run_year, hand_coded == "TRUE") |> rkey() |> unique()

  # What needs coding: no run yet, or areas_raw / model / prompt changed since the run. Never hand-coded keys.
  done <- runs_old |> filter(as.integer(year) == run_year) |>
    filter(coded_by == "rule" | (code_model == model & code_prompt_ver == prompt_ver)) |> transmute(key = rkey(pick(everything())), areas_hash)
  todo <- snap |> filter(!key %in% protected) |> anti_join(done, by = c("key", "areas_hash"))
  no_areas <- filter(todo, is.na(areas_raw) | str_squish(areas_raw) == "")
  to_code <- anti_join(todo, no_areas, by = "key")
  message(sprintf("in scope %d | to code %d | no areas (rule) %d | reused or hand-coded %d", nrow(snap), nrow(to_code), nrow(no_areas), nrow(snap) - nrow(todo)))

  new_runs <- no_areas |> transmute(person_id, year = run_year, inst_id, areas_hash, n_codes = 0L, more_available = FALSE, review_flag = TRUE,
                                    review_note = "no research areas listed", coded_by = "rule", code_model = NA_character_,
                                    code_prompt_ver = NA_character_, batch_tokens_input = NA_integer_, batch_tokens_output = NA_integer_)
  new_areas <- tibble(person_id = character(), year = integer(), inst_id = character(), area_code = character(), area_order = integer(),
                      matched_text = character(), code_model = character(), code_prompt_ver = character(), hand_coded = logical())
  if (nrow(to_code) > 0) {
    if (is.null(sp)) sp <- load_system_prompt(code_prompt_file)
    spent <- \() if (file.exists(usage_log_file)) { u <- summarize_usage(); sum(u$usd[u$step == "code"]) } else 0
    batches <- split(to_code, ceiling(seq_len(nrow(to_code)) / batch_size))
    for (i in seq_along(batches)) {
      if (spent() > budget_usd) { message("coding budget reached: stopping with ", i - 1, " of ", length(batches), " batches done"); break }
      b <- batches[[i]]
      res <- coder(transmute(b, person_id = key, areas_raw, title_raw), sp, batch_label = paste0("areas_", run_year, "_batch_", i))
      meta <- b |> select(key, person_id, inst_id, areas_hash)
      new_runs <- bind_rows(new_runs, res$persons |> rename(key = person_id) |> inner_join(meta, by = "key") |>
        transmute(person_id, year = run_year, inst_id, areas_hash, n_codes = as.integer(n_codes), more_available, review_flag, review_note,
                  coded_by = "model", code_model, code_prompt_ver, batch_tokens_input = as.integer(tokens_input), batch_tokens_output = as.integer(tokens_output)))
      if (nrow(res$areas) > 0)
        new_areas <- bind_rows(new_areas, res$areas |> rename(key = person_id) |> inner_join(meta, by = "key") |>
          transmute(person_id, year = run_year, inst_id, area_code = as.character(area_code), area_order = as.integer(area_order), matched_text,
                    code_model, code_prompt_ver, hand_coded = FALSE))
      message(sprintf("  batch %d/%d coded", i, length(batches)))
    }
  }

  # Merge: keep earlier rows for keys not re-coded; drop rows for keys that left scope this year (unless hand-coded).
  fresh_keys <- unique(c(rkey(new_runs), rkey(no_areas)))
  keep_runs <- runs_old |> filter(!(as.integer(year) == run_year & (rkey(pick(everything())) %in% fresh_keys | !rkey(pick(everything())) %in% snap$key)))
  runs <- bind_rows(keep_runs |> mutate(across(c(n_codes, batch_tokens_input, batch_tokens_output), as.integer),
                                        across(c(more_available, review_flag), as.logical), year = as.integer(year)),
                    new_runs |> mutate(year = as.integer(year))) |>
    select(all_of(runs_cols)) |> arrange(year, inst_id, person_id)
  keep_areas <- areas_old |> filter(!(as.integer(year) == run_year & hand_coded != "TRUE" &
                                                   (rkey(pick(everything())) %in% fresh_keys | !rkey(pick(everything())) %in% snap$key))) |>
    mutate(across(c(year, area_order), as.integer), hand_coded = as.logical(hand_coded))
  areas <- bind_rows(keep_areas, new_areas |> mutate(year = as.integer(year))) |> select(all_of(areas_cols)) |> arrange(year, inst_id, person_id, area_order)

  write_csv(runs, runs_f); write_csv(areas, areas_f)
  # Put coding flags and notes on this year's snapshot rows (build_tables does the same on rebuild).
  all_snap <- read_csv(snap_f, show_col_types = FALSE, col_types = cols(.default = "c", year = "i", named_chair = "l", distinguished = "l", included = "l", review_flag = "l", retrieved = "D"))
  write_csv(bind_rows(filter(all_snap, year != run_year), apply_coding_flags(filter(all_snap, year == run_year), runs)) |>
              arrange(year, inst_id, person_id), snap_f)
  invisible(list(runs = runs, areas = areas))
}
