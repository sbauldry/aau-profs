# Score the finished hand-coding sheet against the pipeline (codebook §7). Usage: Rscript R/26_score_validation.R
# Reads validation/sample_key_2026.csv and validation/handcode_done_2026.csv; writes validation/results_2026.md and results_by_section_2026.csv.
source("R/validate.R")
key <- read_csv("validation/sample_key_2026.csv", show_col_types = FALSE, col_types = cols(.default = "c"))
sheet <- read_csv("validation/handcode_done_2026.csv", show_col_types = FALSE, col_types = cols(.default = "c"))
r <- score_validation(key, sheet)
write_csv(r$per_section, "validation/results_by_section_2026.csv")
fmt <- \(x) paste(capture.output(print(x, n = 100, width = 160)), collapse = "\n")
writeLines(c(sprintf("# Validation results, 2026 (%s)", Sys.Date()), "",
  sprintf("Sample rows: %d; coded: %d.", r$n_rows, r$n_coded), "",
  "## Rank (percent agreement)", "```", fmt(r$rank), "```", "Disagreements:", "```", fmt(r$rank_disagreements), "```",
  "## Inclusion (percent agreement where the pipeline decided)", "```", fmt(r$inclusion), "", fmt(r$inclusion_table), "```", "Disagreements:", "```", fmt(r$inclusion_disagreements), "```",
  "## Area codes (people in scope by both coders)", "```", fmt(r$areas), "```",
  "Per-section presence/absence Krippendorff's alpha, with the number of cases per section:", "```", fmt(r$per_section), "```"),
  "validation/results_2026.md")
cat(readLines("validation/results_2026.md"), sep = "\n")
