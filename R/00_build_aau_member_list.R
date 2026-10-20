# Build the dated AAU member list from a hand-saved copy of AAU's members page and diff it against the previous list.
# Usage: Rscript R/00_build_aau_member_list.R [path]       (default: the newest data/hand_collected/aau_members__*.{csv,txt,html})
# Writes data/seeds/aau_members_<date>.csv and logs/aau_members_diff_<date>.md. Stops (writes nothing) if the parse looks wrong.
# Why by hand: AAU's page blocked automated access on 2026-10-21; codebook §10 says do not work around blocks.
source("R/aau_members.R"); source("R/run_config.R")

p <- run_paths()
args <- commandArgs(trailingOnly = TRUE)
f <- if (length(args)) args[[1]] else { fs <- list.files(p$hand_dir, "^aau_members__\\d{4}-\\d{2}-\\d{2}\\.(csv|txt|html?)$", full.names = TRUE); if (!length(fs)) stop("no aau_members__<date>.{csv,txt,html} in ", p$hand_dir); sort(fs) |> last() }
retrieved <- str_extract(basename(f), "\\d{4}-\\d{2}-\\d{2}"); if (is.na(retrieved)) stop("the file name must carry the retrieval date: aau_members__YYYY-MM-DD.<ext>")
prev_f <- list.files("data/seeds", "^aau_members_\\d{4}-\\d{2}-\\d{2}(_TRIAL)?\\.csv$", full.names = TRUE) |> keep(\(x) !str_detect(x, retrieved)) |> sort() |> last()
previous <- read_csv(prev_f, show_col_types = FALSE, col_types = cols(.default = "c", entry_year = "i"))

parsed <- parse_member_file(f)
lst <- build_member_list(parsed, previous, retrieved)
check_member_list(lst)
d <- diff_members(lst, previous)
new_incomplete <- filter(lst, is.na(sector) | is.na(country))

out <- sprintf("data/seeds/aau_members_%s.csv", retrieved)
write_csv(select(lst, all_of(member_cols)) |> arrange(inst_name), out)
dir.create("logs", showWarnings = FALSE)
fmt <- \(x, cols) if (nrow(x)) paste0("- ", apply(x[cols], 1, paste, collapse = " | ")) else "- none"
writeLines(c(sprintf("# AAU member list, retrieved %s", retrieved), "",
  sprintf("Source: `%s` (saved by hand: `%s`). Previous list: `%s`.", aau_source_url, basename(f), basename(prev_f)), "",
  sprintf("Members: %d (previous %d).", d$n_current, d$n_previous), "",
  "## Added", fmt(d$added, c("inst_name", "entry_year")), "", "## Removed", fmt(d$removed, c("inst_name", "entry_year")), "",
  "## Possible renames (close names, one added and one removed)", fmt(d$renamed_candidates, c("old", "new")), "",
  "## Entry year changed", fmt(d$year_changed, c("inst_name", "entry_year_prev", "entry_year")), "",
  "## Need sector or country filled in by hand", fmt(new_incomplete, c("inst_name", "sector", "country"))),
  sprintf("logs/aau_members_diff_%s.md", retrieved))
cat("wrote", out, "-", nrow(lst), "members;", nrow(d$added), "added,", nrow(d$removed), "removed,", nrow(d$renamed_candidates), "possible renames,", nrow(new_incomplete), "incomplete\n")
if (nrow(d$added) + nrow(d$removed)) cat("MEMBERSHIP CHANGED: see logs/aau_members_diff_", retrieved, ".md; a new member needs a row in institutions_seed_candidates.csv and a URL check.\n", sep = "")
