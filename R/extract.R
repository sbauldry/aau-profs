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
  as_extract_tibble(chat$chat_structured(input, type = extract_schema_v1)) |>
    mutate(source_url = page_url, retrieved = as.character(retrieved),
           extract_model = model, extract_prompt_ver = extract_prompt_ver, .before = 1)
}

listing_context_text <- function(rank, appointment_type, listing_section, rank_evidence) {
  str_glue("rank: {rank}\nappointment_type: {appointment_type}\nlisting_section: {listing_section}\nrank_evidence: {rank_evidence}")
}
