# Build `people`, `snapshots` and the person_id registry from the merged profile-step files.
# Usage (project root):  Rscript R/14_build_tables.R
# Optional env: TABLES_IN (default data/interim/profiles_trial), TABLES_OUT (default
# data/interim/tables_trial), TABLES_YEAR (default 2026).
# The trial writes under data/interim/ on purpose: IDs are never reused (codebook §3.2a), so trial
# IDs must not enter the production registry at data/final/person_id_registry.csv. Production runs
# set TABLES_OUT=data/final.
source("R/build_tables.R")

p <- run_paths()   # RUN=production reads data/interim/<year>/profiles and writes data/final
in_dir <- p$profile_dir; out_dir <- p$tables_dir; yr <- p$year

res <- build_tables(in_dir, yr, out_dir)
reg <- registry_read(file.path(out_dir, "person_id_registry.csv"))
cat("registry ids:", nrow(reg), " people:", nrow(res$people), " snapshots:", nrow(res$snapshots),
    " unnamed (no ID):", nrow(res$unnamed), "\n")
print(count(res$assigned, match_rule))
print(res$snapshots |> filter(year == yr) |> count(included, review_flag))
run_log("tables", list(people = nrow(res$people), snapshots = nrow(res$snapshots), registry = nrow(reg), unnamed = nrow(res$unnamed)), p = p)
