# Stage 3: run the extraction prompt on one page of scraped text.
# Records the exact model ID and prompt version with every result (codebook.md §9).
library(tidyverse)
library(ellmer)
source("R/extract_schema.R")

extract_model <- "claude-sonnet-5-5"
extract_prompt_file <- "prompts/extraction/extract_v1.md"
extract_prompt_ver <- "v1"

load_system_prompt <- function(file = extract_prompt_file) {
  read_file(file) |> str_extract("(?s)# System prompt\\s*(.*)$", group = 1) |> str_trim()
}

# listing_context: NULL for a roster/profile-without-roster page; a short text block with
# rank / appointment_type / listing_section / rank_evidence when `text` is one person's profile.
extract_page <- function(inst_name, page_url, text, retrieved = Sys.Date(), listing_context = NULL,
                         system_prompt = load_system_prompt(), model = extract_model) {
  ctx <- if (is.null(listing_context)) "" else str_glue("listing_context:\n{listing_context}\n\n")
  input <- str_glue("institution: {inst_name}\ndepartment: (as listed on page)\npage_url: {page_url}\n",
                    "retrieved: {retrieved}\n\n{ctx}page_text:\n{text}")
  chat <- chat_anthropic(system_prompt = system_prompt, model = model, echo = "none",
                         params = params(max_tokens = 16000))
  res <- chat$chat_structured(input, type = extract_schema_v1)
  usage <- log_usage(chat, step = "extract", model = model, source_url = page_url,
                     prompt_ver = extract_prompt_ver)
  as_extract_tibble(res) |>
    mutate(source_url = page_url, retrieved = as.character(retrieved),
           extract_model = model, extract_prompt_ver = extract_prompt_ver,
           tokens_input = usage$input, tokens_output = usage$output, .before = 1)
}

# Append one row per API call to logs/api_usage.csv (tokens as reported by the API through ellmer).
# Thinking tokens are included in output. Dollar cost is computed in summarize_usage() from the
# price table below, not taken from ellmer, which may not know newer models.
usage_log_file <- "logs/api_usage.csv"
price_per_mtok <- tribble(          # first-party API rates, USD per million tokens, checked 2026-10-09
  ~model,              ~price_in, ~price_out, ~price_cache_read,
  "claude-sonnet-5-5",      2.00,      10.00,             0.20,
  "claude-opus-5-5",        4.00,      20.00,             0.20)

log_usage <- function(chat, step, model, source_url, prompt_ver, file = usage_log_file) {
  tk <- chat$get_tokens()
  u <- tibble(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), step, model, prompt_ver, source_url,
              input = sum(tk$input, na.rm = TRUE), output = sum(tk$output, na.rm = TRUE),
              cached_input = sum(tk$cached_input, na.rm = TRUE))
  dir.create(dirname(file), showWarnings = FALSE)
  readr::write_csv(u, file, append = file.exists(file))
  u
}

# Totals and approximate dollars from the log. Output includes thinking tokens. Cache reads are
# priced at the cache rate when ellmer reports them; if it reports `input` as including them, the
# estimate is slightly high, never low.
summarize_usage <- function(file = usage_log_file) {
  read_csv(file, show_col_types = FALSE) |>
    left_join(price_per_mtok, by = "model") |>
    mutate(usd = ((input - cached_input) * price_in + cached_input * price_cache_read +
                    output * price_out) / 1e6) |>
    group_by(step, model) |>
    summarise(calls = n(), tokens_in = sum(input), tokens_out = sum(output), usd = sum(usd), .groups = "drop")
}

listing_context_text <- function(rank, appointment_type, listing_section, rank_evidence) {
  str_glue("rank: {rank}\nappointment_type: {appointment_type}\nlisting_section: {listing_section}\nrank_evidence: {rank_evidence}")
}
