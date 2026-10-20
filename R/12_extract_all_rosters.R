# Trial extraction over every scraped roster (prompt v1, Sonnet 5.5). One call per chunk.
# Resumable: institutions with an existing output file are skipped. Stops if the running
# dollar estimate in logs/api_usage.csv passes `budget_usd`.
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/extract.R"); source("R/assemble.R")

p <- run_paths()   # production uses R/30_run_rosters.R (scrape + extract per institution)
out_dir <- p$roster_dir; dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
budget_usd <- p$budget
chunk_chars <- as.numeric(Sys.getenv("CHUNK_CHARS", "9000"))   # lower it to retry rosters that hit max_tokens
cfg <- site_config()
chunks <- readRDS(file.path(p$scrape_dir, "roster_chunks.rds"))
ids <- names(chunks)[map_int(chunks, length) > 0]
sp <- load_system_prompt()

spent <- \() run_spent(p)
for (id in ids) {
  f <- file.path(out_dir, paste0(id, ".csv"))
  if (file.exists(f)) next
  if (spent() > budget_usd) { message("budget reached: stopping"); break }
  row <- filter(cfg, inst_id == id)
  res <- tryCatch(
    # ~9,000-character chunks keep each response well under max_tokens (about 230 output tokens per person)
    imap(chunk_text(paste(chunks[[id]], collapse = "\n\n"), max_chars = chunk_chars), \(txt, i) extract_page(row$inst_name, row$roster_url, txt, system_prompt = sp)) |>
      list_rbind() |> mutate(inst_id = id, .before = 1) |> dedupe_roster(),
    error = \(e) { message("ERROR ", id, ": ", str_sub(conditionMessage(e), 1, 200)); NULL })
  if (!is.null(res)) write_csv(res, f)
  message(sprintf("%-12s records=%s  cumulative usd=%.2f", id, if (is.null(res)) "ERR" else nrow(res), spent()))
}
message("done")
