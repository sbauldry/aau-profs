# End-to-end development test on one institution (Duke): scrape roster -> extract -> scrape
# profiles -> extract with listing_context -> merge -> derive inclusion. Test output only.
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/extract.R"); source("R/assemble.R")

id <- "duke"; year <- "test"; n_profiles <- 6
cfg <- site_config() |> filter(inst_id == id)
sp <- load_system_prompt()
dir.create("data/interim/e2e_test", showWarnings = FALSE)

# 1-2. roster scrape + extraction (one call per chunk)
rost <- scrape_roster(as.list(cfg), year)
roster <- imap(rost$chunks, \(txt, i) extract_page(cfg$inst_name, cfg$roster_url, txt, system_prompt = sp)) |>
  list_rbind() |> mutate(inst_id = id, .before = 1) |> dedupe_roster()
cat("roster records:", nrow(roster), " chunks:", length(rost$chunks), "\n")
print(count(roster, rank))

# 3-4. profiles for full-rank people with a profile link (bounded for the test)
targets <- roster |> filter(rank == "full", !is.na(profile_url)) |> slice_head(n = n_profiles)
profiles <- pmap(targets, \(...) {
  r <- list(...)
  pg <- scrape_profile(id, r$profile_url, cfg$profile_method, year)
  if (is.na(pg$text)) return(NULL)
  ctx <- listing_context_text(r$rank, r$appointment_type, r$listing_section, r$rank_evidence)
  extract_page(cfg$inst_name, r$profile_url, pg$text, listing_context = ctx, system_prompt = sp)
}) |> list_rbind()

# 5-6. merge and derive inclusion
final <- roster |> merge_profile(profiles) |> derive_included() |> mutate(year = 2026, .after = inst_id)
write_csv(roster, "data/interim/e2e_test/duke_roster.csv")
write_csv(profiles, "data/interim/e2e_test/duke_profiles.csv")
write_csv(final, "data/interim/e2e_test/duke_merged.csv")
close_browser()

cat("\nprofiles extracted:", nrow(profiles), "\n")
print(final |> count(rank, included, review_flag))
print(final |> filter(has_profile) |> select(name_raw, rank, appointment_type, included, review_flag, areas_raw) |>
        mutate(areas_raw = str_trunc(areas_raw, 60)), width = 200)
