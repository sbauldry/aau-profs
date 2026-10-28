# Phase 1: re-verify every institution's faculty URL inside the collection window, and retry the hand-collect sites once.
# One polite request per institution (robots.txt, identified user-agent, 2 s delay); blocks are never worked around.
# Writes data/interim/<year>/seed_url_check.csv and logs/seed_refresh_<date>.md; updates data/seeds/institutions_seed.csv
# only for (a) url_verified on pages that still load, and (b) hand-collect sites that now answer (status becomes "reachable").
# Pages that stopped loading are listed for review, not changed.
# Usage: RUN=production Rscript R/32_refresh_seed_urls.R
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/run_config.R")

p <- run_paths(); today <- Sys.Date()
seed <- read_csv("data/seeds/institutions_seed.csv", show_col_types = FALSE, col_types = cols(.default = "c"))
cfg <- site_config() |> filter(method != "none")
check <- function(row) {
  m <- if (row$method == "hand") "http" else row$method          # hand-collect sites get one polite retry with the plain scraper
  pg <- scrape_page(row$inst_id, row$roster_url, m, "recheck", file.path(tempdir(), row$inst_id), tag = "x")
  mf <- pg$manifest
  tibble(inst_id = row$inst_id, config_method = row$method, tried = m, status = mf$status[[1]], robots_ok = mf$robots_ok[[1]],
         text_chars = mf$text_chars[[1]], has_professor = !is.na(pg$text) && str_detect(pg$text, regex("professor", TRUE)),
         note = mf$note[[1]], checked = as.character(today))
}
res <- map(seq_len(nrow(cfg)), \(i) { message(sprintf("[%d/%d] %s", i, nrow(cfg), cfg$inst_id[i])); tryCatch(check(cfg[i, ]), error = \(e) tibble(inst_id = cfg$inst_id[i], config_method = cfg$method[i], tried = NA, status = "error", robots_ok = NA, text_chars = NA_integer_, has_professor = FALSE, note = str_sub(conditionMessage(e), 1, 120), checked = as.character(today))) }) |> list_rbind()
close_browser()
res <- res |> mutate(outcome = case_when(!is.na(text_chars) & text_chars >= 500 & has_professor ~ "ok", status == "blocked" ~ "blocked", status == "skipped" ~ "disallowed by robots.txt", TRUE ~ "check"))
dir.create(p$scrape_dir, recursive = TRUE, showWarnings = FALSE)
write_csv(res, file.path(dirname(p$scrape_dir), "seed_url_check.csv"))

now_ok_hand <- res |> filter(config_method == "hand", outcome == "ok")                  # hand-collect site that now answers
regress <- res |> filter(config_method != "hand", outcome != "ok")                       # a page that used to work and does not now
still_hand <- res |> filter(config_method == "hand", outcome != "ok")
seed2 <- seed |> mutate(url_verified = if_else(inst_id %in% res$inst_id[res$outcome == "ok"], as.character(today), url_verified),
                        notes = if_else(inst_id %in% now_ok_hand$inst_id, paste0("Answered the polite scraper on ", today, " (earlier status: ", url_status, ")."), notes),
                        url_status = if_else(inst_id %in% now_ok_hand$inst_id, "reachable", url_status))
write_csv(seed2, "data/seeds/institutions_seed.csv", na = "NA")
fmt <- \(x, cols) if (nrow(x)) paste0("- ", apply(x[cols], 1, paste, collapse = " | ")) else "- none"
writeLines(c(sprintf("# Seed URL refresh, %s", today), "", sprintf("Institutions checked: %d. OK: %d.", nrow(res), sum(res$outcome == "ok")), "",
  "## Hand-collect sites that now answer (status set to reachable)", fmt(now_ok_hand, c("inst_id", "text_chars")), "",
  "## Hand-collect sites still blocked (collect by hand after the run)", fmt(still_hand, c("inst_id", "outcome", "note")), "",
  "## Pages that did not load this time (not changed; review)", fmt(regress, c("inst_id", "config_method", "status", "outcome", "note"))),
  sprintf("logs/seed_refresh_%s.md", today))
run_log("seed_refresh", list(checked = nrow(res), ok = sum(res$outcome == "ok"), now_reachable = nrow(now_ok_hand), still_hand = nrow(still_hand), need_review = nrow(regress)), p = p)
cat("checked", nrow(res), "| ok", sum(res$outcome == "ok"), "| hand now reachable", nrow(now_ok_hand), "| still hand", nrow(still_hand), "| need review", nrow(regress), "\n")
