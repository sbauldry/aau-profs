# Stage 4: code stored research areas to ASA sections (codebook.md §5, §5.1) with the coding prompt.
# Separate from extraction (CLAUDE.md pipeline stage 4). Records the exact model ID and prompt
# version with every result (codebook.md §9).
library(tidyverse)
library(ellmer)
source("R/code_schema.R"); source("R/extract.R")   # extract.R supplies log_usage() and load_system_prompt()

code_model <- "claude-opus-5-5"
code_prompt_file <- "prompts/coding/code_v1.md"
code_prompt_ver <- "v1"

# recs: tibble with person_id, areas_raw, title_raw (one batch, about 20 people).
# Returns list(persons = one row per person, areas = one row per person x assigned code).
code_batch <- function(recs, system_prompt = load_system_prompt(code_prompt_file), model = code_model, batch_label = "batch", raw_dir = NULL) {
  input <- recs |> transmute(person_id, areas_raw = coalesce(areas_raw, ""), title_raw = coalesce(title_raw, "")) |>
    jsonlite::toJSON(auto_unbox = TRUE)
  chat <- chat_anthropic(system_prompt = system_prompt, model = model, echo = "none", params = params(max_tokens = 16000))
  res <- chat$chat_structured(as.character(input), type = code_schema_v1())
  usage <- log_usage(chat, step = "code", model = model, source_url = batch_label, prompt_ver = code_prompt_ver)
  if (!is.null(raw_dir)) { dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE); saveRDS(res, file.path(raw_dir, paste0(batch_label, ".rds"))) }
  as_code_tibbles(res, recs$person_id, model, usage)
}

# Checks the model's output against the input and the rules the prompt cannot guarantee.
as_code_tibbles <- function(res, input_ids, model, usage) {
  # ellmer simplifies an array of objects to a data frame; `codes` is then a list-column of data frames.
  r <- res$results
  ids <- as.character(r$person_id)
  if (!identical(ids, as.character(input_ids))) stop("coding output does not match input IDs/order: expected ", length(input_ids), ", got ", length(ids))
  codes_of <- \(i) { cd <- r$codes[[i]]; if (is.null(cd) || NROW(cd) == 0) tibble(area_code = character(), matched_text = character()) else as_tibble(cd) }
  persons <- map_dfr(seq_len(nrow(r)), \(i) {
    cds <- codes_of(i)$area_code
    note <- str_squish(r$review_note[i]); flag <- r$review_flag[i]
    # Safeguards for rules the model may miss: an empty code set, `other`, more than three, or a repeat.
    if (length(cds) == 0 && !flag) { flag <- TRUE; note <- paste(c(note, "no codes assigned (flag added by code)"), collapse = "; ") }
    if ("other" %in% cds && !flag) { flag <- TRUE; note <- paste(c(note, "other assigned (flag added by code)"), collapse = "; ") }
    if (length(cds) > 3 || anyDuplicated(cds)) { flag <- TRUE; note <- paste(c(note, "more than 3 codes or repeated code (check)"), collapse = "; ") }
    tibble(person_id = ids[i], n_codes = length(cds), more_available = r$more_available[i],
           review_flag = flag, review_note = na_if(str_squish(note), ""))
  }) |> mutate(code_model = model, code_prompt_ver = code_prompt_ver, tokens_input = usage$input, tokens_output = usage$output)
  areas <- map_dfr(seq_len(nrow(r)), \(i) {
    cd <- codes_of(i)
    if (nrow(cd) == 0) return(NULL)
    mutate(cd, person_id = ids[i], area_order = row_number(), .before = 1)
  }) |> mutate(code_model = model, code_prompt_ver = code_prompt_ver, hand_coded = FALSE)
  list(persons = persons, areas = areas)
}
