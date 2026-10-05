# Development test: fetch a few individual profile pages (one GET each, codebook.md §10)
# and run extraction prompt v1 on them. Test output only; not written to analytic tables.
library(tidyverse)
library(rvest)
library(httr2)
library(robotstxt)
library(ellmer)
source("R/extract_schema.R")

model_id <- "claude-sonnet-5-5"
prompt_ver <- "v1"
system_prompt <- read_file("prompts/extraction/extract_v1.md") |>
  str_extract("(?s)# System prompt\\s*(.*)$", group = 1) |> str_trim()
ua <- str_glue("aau-profs-research/1.0 (academic research; contact: {Sys.getenv('SCRAPER_CONTACT')})")
seed <- read_csv("data/seeds/institutions_seed.csv", show_col_types = FALSE)

names_to_test <- c("Carla A. Pfeffer", "Barbara Schneider",
                   "Corey M. Abramson", "Elaine Howard Ecklund", "Bridget K. Gorman",
                   "Light, Michael", "Emirbayer, Mustafa", "Rogers, Joel")
roster <- read_csv("data/interim/extract_test_v1_links.csv", show_col_types = FALSE) |>
  filter(name_raw %in% names_to_test) |> select(inst_id, name_raw, profile_url)

fetch_profile <- function(inst_id, name_raw, profile_url) {
  Sys.sleep(2)
  if (isFALSE(paths_allowed(profile_url, user_agent = "aau-profs-research", warn = FALSE, force = TRUE)))
    return(tibble(inst_id, name_raw, profile_url, status = NA, text = NA_character_, note = "robots disallow"))
  resp <- request(profile_url) |> req_user_agent(ua) |> req_timeout(30) |>
    req_error(is_error = \(r) FALSE) |> req_perform()
  slug <- str_replace_all(name_raw, "[^A-Za-z]", "")
  writeLines(resp_body_string(resp), file.path("data/raw_html", str_glue("{inst_id}_profile_{slug}.html")))
  node <- resp_body_html(resp) |> html_element("main, body")
  for (a in html_elements(node, "a")) {
    href <- html_attr(a, "href")
    if (!is.na(href) && !str_detect(href, "^(#|mailto:|tel:|javascript:)"))
      xml2::xml_text(a) <- str_glue("{str_squish(html_text2(a))} <{url_absolute(href, profile_url)}>")
  }
  tibble(inst_id, name_raw, profile_url, status = resp_status(resp),
         text = html_text2(node) |> str_replace_all("\n{3,}", "\n\n"), note = NA_character_)
}

pages <- pmap(roster, fetch_profile) |> list_rbind()
print(select(pages, inst_id, name_raw, status, note) |> mutate(chars = nchar(pages$text)))

if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY"))) { message("No API key: fetch only."); quit(save = "no") }

run_one <- function(inst_id, name_raw, profile_url, text, ...) {
  row <- filter(seed, inst_id == !!inst_id)
  input <- str_glue("institution: {row$inst_name}\ndepartment: (as listed on page)\n",
                    "page_url: {profile_url}\nretrieved: {Sys.Date()}\n\npage_text:\n{text}")
  chat <- chat_anthropic(system_prompt = system_prompt, model = model_id, echo = "none",
                         params = params(max_tokens = 16000))
  as_extract_tibble(chat$chat_structured(input, type = extract_schema_v1)) |>
    mutate(inst_id = inst_id, roster_name = name_raw, source_url = profile_url,
           extract_model = model_id, extract_prompt_ver = prompt_ver, run_type = "test", .before = 1)
}

out <- pages |> filter(status %in% 200) |> pmap(run_one) |> list_rbind()
write_csv(out, "data/interim/extract_test_v1_profiles.csv")
print(select(out, roster_name, name_raw, rank, appointment_type, named_chair, distinguished, review_flag), width = 200)
