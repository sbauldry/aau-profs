# Build the `changes` table for one year against the prior year.
# Usage: Rscript R/16_build_changes.R
# Env: TABLES_OUT (default data/interim/tables_trial; production: data/final), TABLES_YEAR (default 2026).
# With no prior year in `snapshots` it writes an empty table (the first collection year has no changes).
# Hand-entered `resolution` and `verified_by` are kept across reruns.
source("R/changes.R")

out_dir <- Sys.getenv("TABLES_OUT", "data/interim/tables_trial")
yr <- as.integer(Sys.getenv("TABLES_YEAR", "2026"))
snap <- read_csv(file.path(out_dir, "snapshots.csv"), show_col_types = FALSE,
                 col_types = cols(.default = "c", year = "i", named_chair = "l", distinguished = "l", included = "l", review_flag = "l"))
prior_year <- snap |> filter(year < yr) |> pull(year) |> max(-Inf)
nc_f <- file.path(out_dir, sprintf("name_changes_%s.csv", yr))
nc <- if (file.exists(nc_f)) read_csv(nc_f, show_col_types = FALSE, col_types = cols(.default = "c", year = "i")) else NULL
ch_f <- file.path(out_dir, "changes.csv")
existing <- if (file.exists(ch_f)) read_csv(ch_f, show_col_types = FALSE, col_types = cols(.default = "c", year = "i")) |> filter(year == yr) else NULL

if (is.infinite(prior_year)) {
  message("No prior year in snapshots: nothing to compare. Writing an empty changes table.")
  res <- list(changes = empty_changes(), unresolved = tibble())
} else {
  res <- build_changes(snap, yr, prior_year, nc, existing)
}
# Replace this year's rows; keep other years.
old <- if (file.exists(ch_f)) read_csv(ch_f, show_col_types = FALSE, col_types = cols(.default = "c", year = "i")) |> filter(year != yr) else empty_changes()
write_csv(bind_rows(old, res$changes), ch_f)
write_csv(res$unresolved, file.path(out_dir, sprintf("changes_unresolved_%s.csv", yr)))
cat("year", yr, "vs", prior_year, ": changes =", nrow(res$changes), " unresolved =", nrow(res$unresolved), "\n")
print(count(res$changes, change_type))
