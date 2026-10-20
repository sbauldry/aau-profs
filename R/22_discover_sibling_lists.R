# Discover sibling faculty lists (emeriti, affiliated, joint, adjunct, visiting, non-tenure-line) linked from
# each institution's faculty page. Writes candidates for review to data/seeds/institution_pages_candidates.csv;
# the reviewed list is data/seeds/institution_pages.csv (inst_id, list_type, page_url, label).
# Polite and robots-aware (scrape_page); one fetch per institution. Blocked pages are not worked around.
# Usage: Rscript R/22_discover_sibling_lists.R
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R")

types <- tribble(
  ~list_type,    ~pattern,
  "emeriti",     "emerit|retired faculty|former faculty",
  "joint",       "\\bjoint\\b",
  "affiliated",  "affiliat|associated faculty|courtesy|cross-appoint|secondary appoint|faculty associate|fellows",
  "adjunct",     "adjunct",
  "visiting",    "visiting",
  "nontenure",   "lecturer|teaching (faculty|professor)|clinical|professors? of the practice|research (faculty|professor|scientist)|instructors?\\b|academic (administrator|staff)")
reject <- "news|event|course|program|degree|seminar|award|job|opening|search|position|colloquia|talk|publication|alumni|student|graduate|undergrad|major|minor|admission|apply|giving|donat|calendar|hiring|recruit|preparing future|postdoc|staff\\b|visit us|visitor|contact"

cfg <- site_config() |> filter(method %in% c("http", "chromote"))
find_lists <- function(row) {
  pg <- scrape_page(row$inst_id, row$roster_url, row$method, "discover", file.path("data/raw_html/trial", row$inst_id), tag = "faculty_page")
  if (is.na(pg$text)) return(tibble(inst_id = row$inst_id, note = pg$manifest$status[[1]]))
  doc <- read_html(pg$html); base <- pg$manifest$final_url[[1]]
  a <- html_elements(doc, "a")
  tibble(label = str_squish(html_text2(a)), href = html_attr(a, "href")) |>
    filter(!is.na(href), !str_detect(href, "^(#|mailto:|tel:|javascript:)")) |>
    mutate(page_url = url_absolute(href, base) |> str_remove("#.*$"), host = url_host(page_url), base_host = url_host(base)) |>
    filter(host == base_host | str_detect(base_host, fixed(str_remove(host, "^www\\."))) | str_detect(host, fixed(str_remove(base_host, "^www\\."))),
           nchar(label) > 0, nchar(label) <= 70, page_url != str_remove(base, "#.*$")) |>
    mutate(hay = str_to_lower(paste(label, str_extract(page_url, "(?<=//[^/]{0,80}/).*$")))) |>
    filter(!str_detect(str_to_lower(label), reject)) |>
    rowwise() |> mutate(list_type = { m <- types$list_type[map_lgl(types$pattern, \(p) str_detect(hay, p))]; if (length(m)) m[[1]] else NA_character_ }) |> ungroup() |>
    filter(!is.na(list_type)) |> distinct(page_url, .keep_all = TRUE) |>
    transmute(inst_id = row$inst_id, list_type, label, page_url, note = NA_character_)
}
res <- map(seq_len(nrow(cfg)), \(i) { message(cfg$inst_id[i]); tryCatch(find_lists(cfg[i, ]), error = \(e) tibble(inst_id = cfg$inst_id[i], note = paste("error:", str_sub(conditionMessage(e), 1, 100)))) }) |> list_rbind()
close_browser()
write_csv(res, "data/seeds/institution_pages_candidates.csv")
cat("institutions:", nrow(cfg), " with candidates:", n_distinct(res$inst_id[!is.na(res$list_type)]), " candidates:", sum(!is.na(res$list_type)), "\n")
print(count(res, list_type)); print(res |> filter(!is.na(note)), n = 30)
