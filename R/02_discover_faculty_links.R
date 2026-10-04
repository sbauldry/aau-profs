# Stage 1, pass 2: for candidates that failed pass 1, fetch the site root once and
# list links that look like faculty directories. Conduct rules: codebook.md §10.
library(tidyverse)
library(httr2)
library(rvest)
library(robotstxt)

ua <- str_glue("aau-profs-research/1.0 (academic research; contact: {Sys.getenv('SCRAPER_CONTACT')})")
chk <- read_csv("data/interim/seed_url_check.csv", show_col_types = FALSE)

good <- chk$status %in% 200 & chk$has_sociology %in% TRUE & chk$has_professor %in% TRUE &
  str_detect(coalesce(chk$final_url, ""), "faculty|people|directory|professors|staff")
todo <- chk |> filter(!good, !is.na(url), nzchar(url)) |>
  mutate(root = str_extract(url, "^https?://[^/]+"))

find_links <- function(inst_id, root) {
  Sys.sleep(2)
  if (isFALSE(tryCatch(paths_allowed(root, user_agent = "aau-profs-research", warn = FALSE, force = TRUE),
                       error = \(e) NA))) return(tibble(inst_id, note = "robots disallow"))
  resp <- tryCatch(request(root) |> req_user_agent(ua) |> req_timeout(30) |>
                     req_error(is_error = \(r) FALSE) |> req_perform(), error = identity)
  if (inherits(resp, "error")) return(tibble(inst_id, note = str_sub(conditionMessage(resp), 1, 80)))
  if (resp_status(resp) >= 400) return(tibble(inst_id, note = paste("status", resp_status(resp))))
  pg <- tryCatch(resp_body_html(resp), error = identity)
  if (inherits(pg, "error")) return(tibble(inst_id, note = "unparseable"))
  a <- html_elements(pg, "a")
  tibble(inst_id, text = str_squish(html_text2(a)), href = html_attr(a, "href")) |>
    filter(str_detect(paste(text, href), regex("faculty|people|directory|professor", TRUE)),
           !is.na(href)) |>
    mutate(href = url_absolute(href, resp_url(resp))) |> distinct(href, .keep_all = TRUE) |>
    slice_head(n = 8)
}

res <- map2(todo$inst_id, todo$root, find_links) |> list_rbind()
write_csv(res, "data/interim/seed_link_discovery.csv")
