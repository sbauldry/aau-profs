# Build `people`, `snapshots` and the person_id registry from the merged profile-step files.
# Usage (project root):  Rscript R/14_build_tables.R
# Optional env: TABLES_IN (default data/interim/profiles_trial), TABLES_OUT (default
# data/interim/tables_trial), TABLES_YEAR (default 2026).
# The trial writes under data/interim/ on purpose: IDs are never reused (codebook §3.2a), so trial
# IDs must not enter the production registry at data/final/person_id_registry.csv. Production runs
# set TABLES_OUT=data/final.
source("R/build_tables.R")

in_dir  <- Sys.getenv("TABLES_IN", "data/interim/profiles_trial")
out_dir <- Sys.getenv("TABLES_OUT", "data/interim/tables_trial")
yr      <- as.integer(Sys.getenv("TABLES_YEAR", "2026"))

res <- build_tables(in_dir, yr, out_dir)
reg <- registry_read(file.path(out_dir, "person_id_registry.csv"))
cat("registry ids:", nrow(reg), " people:", nrow(res$people), " snapshots:", nrow(res$snapshots),
    " unnamed (no ID):", nrow(res$unnamed), "\n")
print(count(res$assigned, match_rule))
print(res$snapshots |> filter(year == yr) |> count(included, review_flag))
