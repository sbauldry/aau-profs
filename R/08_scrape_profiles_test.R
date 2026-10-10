# Development test of profile fetching (after R/07_scrape_test.R has produced roster text).
library(tidyverse)
source("R/scrape.R")
source("R/site_config.R")

year <- "test"
cfg <- site_config()
roster <- readRDS("data/interim/scrape_test/roster_chunks.rds")

# Profile URLs: rice and wisc from the earlier extraction test; duke from links in the roster text
ext <- read_csv("data/interim/extract_test_v1_links.csv", show_col_types = FALSE)
pick <- bind_rows(
  ext |> filter(inst_id %in% c("rice", "wisc")) |> group_by(inst_id) |> slice_head(n = 3) |> ungroup() |>
    select(inst_id, url = profile_url),
  tibble(inst_id = "duke",
         url = str_extract_all(paste(roster$duke, collapse = "\n"), "https://scholars\\.duke\\.edu/person/[A-Za-z0-9._-]+") |>
           unlist() |> unique() |> head(3)),
  tibble(inst_id = "msu", url = "https://sociology.msu.edu/people/directory/pfeffer-carla.html"))

man <- list()
for (i in seq_len(nrow(pick))) {
  pm <- cfg$profile_method[cfg$inst_id == pick$inst_id[i]]
  if (pm == "hand") {
    man[[i]] <- manifest_row(pick$inst_id[i], "profile", pick$url[i], "hand", "skipped", note = "profile pages block automated access; collect by hand")
  } else {
    man[[i]] <- scrape_profile(pick$inst_id[i], pick$url[i], pm, year)$manifest
  }
}
man <- list_rbind(man)
write_csv(man, "data/interim/scrape_test/manifest_profiles.csv")
print(man |> select(inst_id, method, status, text_chars, robots_ok, note), width = 200)
