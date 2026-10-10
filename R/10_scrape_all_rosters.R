# Trial scrape of every roster page (no API calls). One request per page; conduct rules in
# R/scrape.R / codebook.md §10. Writes a manifest and the roster text for later extraction.
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R")

year <- "trial"
out_dir <- "data/interim/scrape_trial"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cfg <- site_config()
only <- commandArgs(trailingOnly = TRUE)        # optional inst_ids to (re)scrape; merged into existing output
chunks <- list(); manifest <- list()
if (length(only)) {
  chunks <- readRDS(file.path(out_dir, "roster_chunks.rds"))
  old <- read_csv(file.path(out_dir, "manifest_roster.csv"), col_types = cols(.default = "c")) |>
    filter(!inst_id %in% only)
  manifest <- split(old, old$inst_id)
  cfg <- filter(cfg, inst_id %in% only)
}
for (i in seq_len(nrow(cfg))) {
  id <- cfg$inst_id[i]
  r <- tryCatch(scrape_roster(as.list(cfg[i, ]), year),
                error = \(e) list(chunks = character(),
                                  manifest = manifest_row(id, "roster", cfg$roster_url[i], cfg$method[i], "error",
                                                          note = str_sub(conditionMessage(e), 1, 160))))
  chunks[[id]] <- r$chunks; manifest[[id]] <- r$manifest
  write_csv(list_rbind(map(manifest, \(d) mutate(d, across(everything(), as.character)))),
            file.path(out_dir, "manifest_roster.csv"))   # incremental
  message(sprintf("[%d/%d] %s %s %s", i, nrow(cfg), id, cfg$method[i], paste(unique(r$manifest$status), collapse = ",")))
}
close_browser()
saveRDS(chunks, file.path(out_dir, "roster_chunks.rds"))
message("done")
