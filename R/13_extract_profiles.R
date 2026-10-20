# Profile step: fetch each target person's profile page and extract with listing_context
# (prompt v1, Sonnet 5.5), then merge into the roster extraction and derive `included`.
# Targets: people at rank full (areas and appointment type come from the profile) or unknown
# (rank must be resolved). One call per profile.
#
# Usage (from the project root):
#   INST=utoronto Rscript R/13_extract_profiles.R        # one institution (default: utoronto)
#   INST=pitt,duke Rscript R/13_extract_profiles.R       # comma-separated list
#   INST=all Rscript R/13_extract_profiles.R             # every institution with a roster file
# Optional: MAX_PROFILES=5 (cap per institution, for a dry run), BUDGET_USD=20, RUN_YEAR=trial.
# Resumable: per-profile results are cached, so a rerun only fetches/extracts what is missing.
# Skips institutions whose profile_method is "hand" or "none" (site_config.R). Test output only
# until the production window run (codebook.md §8).
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/extract.R"); source("R/assemble.R")

inst_arg   <- Sys.getenv("INST", "utoronto")
max_n      <- as.numeric(Sys.getenv("MAX_PROFILES", "Inf"))
budget_usd <- as.numeric(Sys.getenv("BUDGET_USD", "20"))
run_year   <- Sys.getenv("RUN_YEAR", "trial")         # folder name under data/raw_html/
roster_dir <- "data/interim/extract_trial"            # roster extractions from script 12
out_dir    <- "data/interim/profiles_trial"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- site_config()
sp <- load_system_prompt()
spent <- \() if (file.exists(usage_log_file)) sum(summarize_usage()$usd) else 0

ids <- if (inst_arg == "all") str_remove(list.files(roster_dir, pattern = "\\.csv$"), "\\.csv$") else str_split_1(inst_arg, ",")
ids <- intersect(ids, cfg$inst_id[!cfg$profile_method %in% c("hand", "none")])

for (id in ids) {
  row <- filter(cfg, inst_id == id)
  roster <- read_csv(file.path(roster_dir, paste0(id, ".csv")), show_col_types = FALSE)
  targets <- roster |>
    filter(rank %in% c("full", "unknown"), !is.na(profile_url)) |>
    distinct(profile_url, .keep_all = TRUE) |> slice_head(n = max_n)
  message(sprintf("%s: %d roster records, %d profile targets", id, nrow(roster), nrow(targets)))

  cache <- file.path(out_dir, id); dir.create(cache, showWarnings = FALSE)
  profiles <- pmap(targets, \(...) {
    r <- list(...)
    f <- file.path(cache, paste0(str_replace_all(str_remove(r$profile_url, "^https?://"), "[^A-Za-z0-9]+", "_") |> str_sub(1, 100), ".csv"))
    if (file.exists(f)) return(read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c")))
    if (spent() > budget_usd) { message("budget reached: stopping"); return(NULL) }
    pg <- scrape_profile(id, r$profile_url, row$profile_method, run_year)
    if (is.na(pg$text)) { message("  no text (", pg$manifest$status, "): ", r$profile_url); return(NULL) }
    ctx <- listing_context_text(r$rank, r$appointment_type, r$listing_section, r$rank_evidence)
    res <- tryCatch(extract_page(row$inst_name, r$profile_url, pg$text, listing_context = ctx, system_prompt = sp),
                    error = \(e) { message("  ERROR ", r$profile_url, ": ", str_sub(conditionMessage(e), 1, 150)); NULL })
    if (is.null(res)) return(NULL)
    # Profile pages describe one person; keep the row that matches the roster record, else the first.
    res <- slice_head(res, n = 1)
    write_csv(res, f)
    mutate(res, across(everything(), as.character))
  }) |> list_rbind()

  if (nrow(profiles) == 0) { message("  no profiles extracted"); next }
  # Re-type cached/new rows consistently before merging.
  profiles <- profiles |> mutate(across(c(named_chair, distinguished, review_flag, text_defect), as.logical),
                                 phd_year = as.integer(phd_year))
  roster <- roster |> mutate(phd_year = as.integer(phd_year))
  final <- roster |> mutate(inst_id = id) |> merge_profile(profiles) |> derive_included()
  write_csv(profiles, file.path(out_dir, paste0(id, "_profiles.csv")))
  write_csv(final, file.path(out_dir, paste0(id, "_merged.csv")))
  cat("\n", id, ": profiles extracted =", nrow(profiles), "\n")
  print(final |> count(rank, included, review_flag))
  print(final |> filter(has_profile, rank %in% c("full", "unknown")) |>
          select(name_raw, rank, appointment_type, included, review_flag) , n = 40, width = 160)
  message(sprintf("%-12s cumulative usd=%.2f", id, spent()))
}
close_browser()
message("done")
