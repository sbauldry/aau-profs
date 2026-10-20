# Stages 2 and 3 for the main faculty lists: scrape each institution's roster, then extract it, one institution at a time.
# Resumable: an institution with an existing output file is skipped; scraped text is cached per institution.
# Usage: RUN=production Rscript R/30_run_rosters.R [inst_id ...]        (no arguments = every institution with a scraping method)
# Conduct rules: codebook §10 (robots.txt, 2 s delay, identified user-agent; blocks are not worked around).
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/extract.R"); source("R/assemble.R")

p <- run_paths(); cfg <- site_config() |> filter(method %in% c("http", "chromote"))
only <- commandArgs(trailingOnly = TRUE); if (length(only)) cfg <- filter(cfg, inst_id %in% only)
chunk_chars <- as.numeric(Sys.getenv("CHUNK_CHARS", "9000"))   # lower it to retry rosters that hit max_tokens
dir.create(file.path(p$scrape_dir, "chunks"), recursive = TRUE, showWarnings = FALSE); dir.create(p$roster_dir, recursive = TRUE, showWarnings = FALSE)
sp <- load_system_prompt(); manifest_f <- file.path(p$scrape_dir, "manifest_roster.csv"); done <- 0L; failed <- character()

for (i in seq_len(nrow(cfg))) {
  row <- cfg[i, ]; id <- row$inst_id
  out <- file.path(p$roster_dir, paste0(id, ".csv")); cf <- file.path(p$scrape_dir, "chunks", paste0(id, ".rds"))
  if (file.exists(out)) next
  if (run_spent(p) > p$budget) { message("budget reached: stopping"); break }
  chunks <- if (file.exists(cf)) readRDS(cf) else {
    r <- tryCatch(scrape_roster(as.list(row), p$raw_year, root = p$raw_html),
                  error = \(e) list(chunks = character(), manifest = manifest_row(id, "roster", row$roster_url, row$method, "error", note = str_sub(conditionMessage(e), 1, 160))))
    m <- mutate(r$manifest, across(everything(), as.character))
    write_csv(if (file.exists(manifest_f)) bind_rows(filter(read_csv(manifest_f, show_col_types = FALSE, col_types = cols(.default = "c")), inst_id != id), m) else m, manifest_f)
    if (length(r$chunks)) saveRDS(r$chunks, cf)
    r$chunks
  }
  if (!length(chunks)) { failed <- c(failed, id); message(sprintf("[%d/%d] %-12s no text (see manifest)", i, nrow(cfg), id)); next }
  res <- tryCatch(imap(chunk_text(paste(chunks, collapse = "\n\n"), max_chars = chunk_chars), \(t, k) extract_page(row$inst_name, row$roster_url, t, system_prompt = sp)) |>
                    list_rbind() |> mutate(inst_id = id, .before = 1) |> dedupe_roster(),
                  error = \(e) { message("  ERROR ", id, ": ", str_sub(conditionMessage(e), 1, 200)); NULL })
  if (is.null(res)) { failed <- c(failed, id); next }
  write_csv(res, out); done <- done + 1L
  message(sprintf("[%d/%d] %-12s records=%-3d spent=%.2f", i, nrow(cfg), id, nrow(res), run_spent(p)))
}
close_browser()
run_log("rosters", list(extracted = done, failed_or_blocked = length(failed)), note = if (length(failed)) paste("no text:", paste(failed, collapse = ", ")) else NULL, p = p)
