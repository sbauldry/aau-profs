# Code research areas and assemble the `areas` table for one year (stage 4 -> codebook §3.4).
# Usage: Rscript R/19_build_areas.R     (run R/14_build_tables.R first)
# Env: TABLES_OUT (default data/interim/tables_trial; production: data/final), TABLES_YEAR (default 2026),
#      CODING_BUDGET_USD (default 5; counts all "code" spend in logs/api_usage.csv)
source("R/areas.R")

p <- run_paths(); out_dir <- p$tables_dir; yr <- p$year
res <- build_areas(out_dir, yr, budget_usd = as.numeric(Sys.getenv("CODING_BUDGET_USD", "5")))
cat("areas rows:", nrow(res$areas), " people with a coding run:", nrow(res$runs), "\n")
print(count(res$runs, coded_by, review_flag))
print(count(res$areas, area_code, sort = TRUE), n = 15)
print(summarize_usage() |> filter(step == "code"))
run_log("areas", list(area_rows = nrow(res$areas), coded_people = nrow(res$runs), flagged = sum(res$runs$review_flag)), p = p)
