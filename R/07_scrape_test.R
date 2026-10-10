# Development test of the stage 2 scraper on a small, varied set of institutions.
# Writes to data/raw_html/test/ (git-ignored) and data/interim/scrape_test/.
library(tidyverse)
source("R/scrape.R")
source("R/site_config.R")

year <- "test"
test_ids <- c("duke", "rice", "wisc", "pitt", "ucriverside", "msu", "harvard", "mit")
cfg <- site_config() |> filter(inst_id %in% test_ids)
print(select(cfg, inst_id, method, profile_method, paginate))

results <- list(); manifest <- list()
for (i in seq_len(nrow(cfg))) {
  r <- scrape_roster(as.list(cfg[i, ]), year)
  results[[cfg$inst_id[i]]] <- r$chunks
  manifest[[i]] <- r$manifest
}
close_browser()

man <- list_rbind(manifest)
dir.create("data/interim/scrape_test", showWarnings = FALSE)
write_csv(man, "data/interim/scrape_test/manifest_roster.csv")
print(man |> select(inst_id, method, status, text_chars, robots_ok, note), n = 40, width = 200)
saveRDS(results, "data/interim/scrape_test/roster_chunks.rds")
cat("\nchunks per institution:\n"); print(map_int(results, length))
