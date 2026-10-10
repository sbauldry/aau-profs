# Rebuild roster text from the saved HTML of a scrape (no requests). Use after improving
# page_to_text() / chunk_text().
library(tidyverse)
source("R/scrape.R")

year <- "trial"; out_dir <- "data/interim/scrape_trial"
man <- read_csv(file.path(out_dir, "manifest_roster.csv"), col_types = cols(.default = "c")) |>
  filter(status == "200", !is.na(html_file))
old <- readRDS(file.path(out_dir, "roster_chunks.rds"))
new <- man |> group_split(inst_id) |> set_names(map_chr(group_split(man, inst_id), \(d) d$inst_id[1])) |>
  map(\(d) {
    texts <- map2_chr(d$html_file, d$final_url, \(f, u) page_to_text(read_file(f), u))
    unlist(map(paste(drop_boilerplate(texts), collapse = "\n\n"), chunk_text))
  })
# hand / none / blocked institutions keep their empty entries
for (id in setdiff(names(old), names(new))) new[[id]] <- character()
cmp <- tibble(inst_id = names(new), chars_before = map_int(old[names(new)], \(x) sum(nchar(x))),
              chars_after = map_int(new, \(x) sum(nchar(x))),
              prof_before = map_int(old[names(new)], \(x) str_count(paste(x, collapse = " "), regex("professor", TRUE))),
              prof_after = map_int(new, \(x) str_count(paste(x, collapse = " "), regex("professor", TRUE)))) |>
  filter(chars_after > 0 | chars_before > 0)
saveRDS(new[names(old)], file.path(out_dir, "roster_chunks.rds"))
cat("total chars before/after:", sum(cmp$chars_before), sum(cmp$chars_after), "\n")
cat("sites where professor mentions dropped:\n"); print(filter(cmp, prof_after < prof_before), n = 30)
cat("largest after:\n"); print(arrange(cmp, desc(chars_after)) |> head(8))
