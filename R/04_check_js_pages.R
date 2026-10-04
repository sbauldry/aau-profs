# Stage 1: open uncertain seed URLs in headless Chrome (chromote) and check whether
# faculty names with ranks render. One page load per institution; codebook.md §10.
library(tidyverse)
library(chromote)

ua <- str_glue("aau-profs-research/1.0 (academic research; contact: {Sys.getenv('SCRAPER_CONTACT')})")
# Args: [input candidate CSV] [output CSV]; default = institutions still needing a content check
args <- commandArgs(trailingOnly = TRUE)
seed <- if (length(args) >= 1) {
  read_csv(args[1], show_col_types = FALSE) |> rename(faculty_url = candidate_url)
} else {
  read_csv("data/seeds/institutions_seed.csv", show_col_types = FALSE) |>
    filter(url_status == "reachable_check_content")
}
out_file <- if (length(args) >= 2) args[2] else "data/interim/seed_js_check.csv"

dir.create("data/raw_html", showWarnings = FALSE)
b <- ChromoteSession$new()
b$Network$setUserAgentOverride(userAgent = ua)

check_page <- function(inst_id, url) {
  Sys.sleep(2)
  res <- tryCatch({
    b$Page$navigate(url, wait_ = FALSE)
    b$Page$loadEventFired(timeout_ = 30)
    Sys.sleep(4)  # allow client-side rendering
    txt <- b$Runtime$evaluate("document.body.innerText")$result$value
    html <- b$Runtime$evaluate("document.documentElement.outerHTML")$result$value
    writeLines(html, file.path("data/raw_html", str_glue("{inst_id}_seedcheck.html")))
    lines <- str_split_1(txt, "\n") |> str_squish() |> discard(\(x) x == "")
    rank_lines <- lines[str_detect(lines, regex("professor", TRUE))]
    tibble(inst_id, n_chars = nchar(txt), n_professor_lines = length(rank_lines),
           has_sociology = str_detect(txt, regex("sociolog", TRUE)),
           sample = paste(head(rank_lines, 4), collapse = " | "), error = NA_character_)
  }, error = \(e) tibble(inst_id, error = conditionMessage(e)))
  res
}

out <- map2(seed$inst_id, seed$faculty_url, check_page) |> list_rbind()
b$close()
write_csv(out, out_file)
print(out, width = 200)
