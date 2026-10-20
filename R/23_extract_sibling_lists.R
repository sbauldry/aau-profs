# Scrape and extract the sibling faculty lists in data/seeds/institution_pages.csv (emeriti, affiliated,
# joint, adjunct, visiting, non-tenure-line). Records are kept so exclusions are auditable (CLAUDE.md,
# codebook §2); `included` for these lists is set by derive_included() in R/assemble.R, not here.
# Usage: Rscript R/23_extract_sibling_lists.R      (env: BUDGET_USD default 20, RUN_YEAR default "trial")
# Resumable: one output file per page. Conduct as everywhere (robots.txt, 2 s delay, blocks not worked around).
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/extract.R"); source("R/assemble.R")

run_year <- Sys.getenv("RUN_YEAR", "trial"); budget_usd <- as.numeric(Sys.getenv("BUDGET_USD", "20"))
out_dir <- "data/interim/extract_trial_siblings"; dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
pages <- read_csv("data/seeds/institution_pages.csv", show_col_types = FALSE)
cfg <- site_config(); sp <- load_system_prompt()
spent <- \() if (file.exists(usage_log_file)) sum(summarize_usage()$usd) else 0
page_file <- \(id, type, url) file.path(out_dir, paste0(id, "__", type, "__", str_sub(digest::digest(url, algo = "md5", serialize = FALSE), 1, 8), ".csv"))
manifest <- list()

for (i in seq_len(nrow(pages))) {
  p <- pages[i, ]; row <- filter(cfg, inst_id == p$inst_id)
  if (!nrow(row) || row$method %in% c("hand", "none")) next
  f <- page_file(p$inst_id, p$list_type, p$page_url)
  if (file.exists(f)) next
  if (spent() > budget_usd) { message("budget reached: stopping"); break }
  pg <- scrape_page(p$inst_id, p$page_url, row$method, paste0("list_", p$list_type), file.path("data/raw_html", run_year, p$inst_id), tag = paste0(p$list_type, "_", i))
  manifest[[length(manifest) + 1]] <- pg$manifest
  if (is.na(pg$text)) { message("  no text (", pg$manifest$status, "): ", p$page_url); next }
  # The page heading is the link text that led here; it stands in for a section heading when the page has none.
  txt <- paste0("Page heading: ", p$label, "\n\n", pg$text)
  res <- tryCatch(
    imap(chunk_text(txt, max_chars = 9000), \(t, k) extract_page(row$inst_name, p$page_url, t, system_prompt = sp)) |> list_rbind() |>
      mutate(inst_id = p$inst_id, list_type = p$list_type, list_label = p$label, .before = 1) |> dedupe_roster(),
    error = \(e) { message("  ERROR ", p$page_url, ": ", str_sub(conditionMessage(e), 1, 150)); NULL })
  if (!is.null(res)) write_csv(res, f)
  message(sprintf("%-10s %-10s records=%-3s usd=%.2f", p$inst_id, p$list_type, if (is.null(res)) "ERR" else nrow(res), spent()))
}
close_browser()
if (length(manifest)) {
  m <- list_rbind(manifest); mf <- sprintf("logs/sibling_lists_manifest_%s.csv", Sys.Date())
  write_csv(if (file.exists(mf)) bind_rows(read_csv(mf, show_col_types = FALSE, col_types = cols(.default = "c")), mutate(m, across(everything(), as.character))) else m, mf)
}
message("done")
