# Discover sibling faculty lists (emeriti, affiliated, joint, adjunct, visiting, non-tenure-line) linked from
# each institution's faculty page. Writes candidates for review to data/seeds/institution_pages_candidates.csv;
# the reviewed list is data/seeds/institution_pages.csv (inst_id, list_type, page_url, label).
# Polite and robots-aware (scrape_page); one fetch per institution. Blocked pages are not worked around.
# Usage: Rscript R/22_discover_sibling_lists.R
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/run_config.R")
p <- run_paths()

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
  pg <- scrape_page(row$inst_id, row$roster_url, row$method, "discover", file.path(p$raw_html, p$raw_year, row$inst_id), tag = "faculty_page")
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

# Apply the same pruning used when the list was curated by hand (2026-10-20): drop links to people, centers, fellowships,
# postdoc and visiting-scholar pages, then compare with the reviewed list. institution_pages.csv itself is never overwritten.
prune_candidates <- function(d) {
  d |> filter(!is.na(list_type)) |>
    filter(!str_detect(label, regex("fellowship|financial support|centers|institutions|guide|scholars|post doctoral|fund|fellows$|mms instructors|resources|grants", TRUE)),
           !str_detect(page_url, regex("/graduate/|alumni|/research/|admin/vis-scholars|commcms/history|node/\\d+|core-department-faculty-member|/emeritus/[a-z-]+\\.html$|/emeriti/[a-z-]+$|/emeritus/[a-z]+/$|faculty/visiting/[a-z-]+\\.html|people/rick-moore|soc-faculty$|people/faculty/emeritus/[a-z-]+\\.html", TRUE))) |>
    filter(!(inst_id == "ufl" & !str_ends(page_url, "emeritus/"))) |>
    mutate(list_type = case_when(inst_id == "ucberkeley" & str_detect(page_url, "visiting") ~ "visiting", inst_id == "upenn" & str_detect(page_url, "lecturers") ~ "nontenure",
                                 inst_id == "yale" & str_detect(page_url, "affiliated-emeritus") ~ "emeriti", TRUE ~ list_type))
}
curated <- read_csv("data/seeds/institution_pages.csv", show_col_types = FALSE)
cand <- prune_candidates(res)
new_lists <- anti_join(cand, curated, by = c("inst_id", "page_url")) |> select(inst_id, list_type, page_url, label)
gone <- anti_join(curated, cand, by = c("inst_id", "page_url"))
dir.create(dirname(p$scrape_dir), recursive = TRUE, showWarnings = FALSE)
write_csv(new_lists, file.path(dirname(p$scrape_dir), "sibling_lists_new.csv")); write_csv(gone, file.path(dirname(p$scrape_dir), "sibling_lists_gone.csv"))
cat("\nreviewed lists:", nrow(curated), "| candidates after pruning:", nrow(cand), "| NEW to review:", nrow(new_lists), "| in the reviewed list but not found now:", nrow(gone), "\n")
if (nrow(new_lists)) print(new_lists, n = 50, width = 200)
if (nrow(gone)) print(gone, n = 50, width = 200)
run_log("sibling_discovery", list(institutions = nrow(cfg), candidates = nrow(cand), new = nrow(new_lists), gone = nrow(gone)), p = p)
cat("institutions:", nrow(cfg), " with candidates:", n_distinct(res$inst_id[!is.na(res$list_type)]), " candidates:", sum(!is.na(res$list_type)), "\n")
print(count(res, list_type)); print(res |> filter(!is.na(note)), n = 30)
