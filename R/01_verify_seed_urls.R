# Stage 1: check candidate faculty-directory URLs (codebook.md §10 conduct rules).
# Input : candidate CSV (arg 1; default data/seeds/institutions_seed_candidates.csv)
# Output: check CSV (arg 2; default data/interim/seed_url_check.csv), one GET per institution

library(tidyverse)
library(httr2)
library(robotstxt)

contact <- Sys.getenv("SCRAPER_CONTACT")
stopifnot(nzchar(contact))
ua <- str_glue("aau-profs-research/1.0 (academic research; contact: {contact})")
delay <- 2  # seconds between requests (§10)

check_url <- function(inst_id, url) {
  out <- tibble(inst_id = inst_id, url = url, robots_ok = NA, status = NA_integer_,
                final_url = NA_character_, has_sociology = NA, has_professor = NA,
                error = NA_character_, checked = Sys.Date())
  if (is.na(url) || !nzchar(url)) return(mutate(out, error = "no candidate url"))

  out$robots_ok <- tryCatch(
    paths_allowed(url, user_agent = "aau-profs-research", warn = FALSE, force = TRUE),
    error = function(e) NA)
  if (isFALSE(out$robots_ok)) return(mutate(out, error = "disallowed by robots.txt"))

  Sys.sleep(delay)
  resp <- tryCatch(
    request(url) |>
      req_user_agent(ua) |>
      req_timeout(30) |>
      req_error(is_error = \(r) FALSE) |>
      req_perform(),
    error = function(e) e)
  if (inherits(resp, "error")) return(mutate(out, error = conditionMessage(resp)))

  body <- tryCatch(resp_body_string(resp), error = \(e) "")
  mutate(out,
         status = resp_status(resp),
         final_url = resp_url(resp),
         has_sociology = str_detect(body, regex("sociolog", ignore_case = TRUE)),
         has_professor = str_detect(body, regex("professor", ignore_case = TRUE)))
}

args <- commandArgs(trailingOnly = TRUE)
in_file <- if (length(args) >= 1) args[1] else "data/seeds/institutions_seed_candidates.csv"
out_file <- if (length(args) >= 2) args[2] else "data/interim/seed_url_check.csv"

res <- read_csv(in_file, show_col_types = FALSE) |>
  select(inst_id, candidate_url) |>
  pmap(\(inst_id, candidate_url) check_url(inst_id, candidate_url)) |>
  list_rbind()

write_csv(res, out_file)
count(res, status, error) |> print(n = Inf)
