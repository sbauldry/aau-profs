# Stage 1: check candidate faculty-directory URLs (codebook.md §10 conduct rules).
# Input : data/seeds/institutions_seed_candidates.csv
# Output: data/interim/seed_url_check.csv  (one row per institution, one GET each)

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

res <- read_csv("data/seeds/institutions_seed_candidates.csv", show_col_types = FALSE) |>
  select(inst_id, candidate_url) |>
  pmap(\(inst_id, candidate_url) check_url(inst_id, candidate_url)) |>
  list_rbind()

write_csv(res, "data/interim/seed_url_check.csv")
count(res, status, error) |> print(n = Inf)
