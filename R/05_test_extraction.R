# Small development test of extraction prompt v1 on cached seed-check pages.
# Not a production run: results go to data/interim/ with a "test" tag, and are not
# written to the analytic tables. Model and prompt version are recorded with the output.
library(tidyverse)
library(rvest)
library(ellmer)
source("R/extract_schema.R")

model_id <- "claude-sonnet-5-5"   # codebook.md §9
prompt_ver <- "v1"
prompt_file <- "prompts/extraction/extract_v1.md"

system_prompt <- read_file(prompt_file) |>
  str_extract("(?s)# System prompt\\s*(.*)$", group = 1) |> str_trim()

seed <- read_csv("data/seeds/institutions_seed.csv", show_col_types = FALSE)
test_ids <- c("rice", "wisc", "msu")

page_text <- function(inst_id) {
  read_html(file.path("data/raw_html", str_glue("{inst_id}_seedcheck.html"))) |>
    html_element("main, body") |> html_text2() |> str_replace_all("\n{3,}", "\n\n")
}

make_input <- function(inst_id) {
  row <- filter(seed, inst_id == !!inst_id)
  str_glue("institution: {row$inst_name}\ndepartment: (as listed on page)\npage_url: {row$faculty_url}\n",
           "retrieved: 2026-10-03\n\npage_text:\n{page_text(inst_id)}")
}

inputs <- set_names(map(test_ids, make_input), test_ids)
cat("input characters:", map_int(inputs, nchar) |> paste(names(inputs), sep = " ", collapse = "; "), "\n")

if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY"))) {
  message("ANTHROPIC_API_KEY not set: dry run only (inputs assembled, no API call).")
  quit(save = "no")
}

run_one <- function(inst_id) {
  chat <- chat_anthropic(system_prompt = system_prompt, model = model_id, echo = "none")
  res <- chat$chat_structured(inputs[[inst_id]], type = extract_schema_v1)
  as_tibble(res$faculty) |>
    mutate(inst_id = inst_id, extract_model = model_id, extract_prompt_ver = prompt_ver,
           run_type = "test", .before = 1)
}

out <- map(test_ids, run_one) |> list_rbind()
write_csv(out, "data/interim/extract_test_v1.csv")
out |> count(inst_id, rank) |> print(n = Inf)
