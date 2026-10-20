# Compare the database built by this pipeline with the hand-built database ("Head - AAU Database.xlsx").
# Names and ranks only (areas later). The hand file has columns Name ("Last, First"), University, Areas,
# Note ("emeritus", "emerita", "not soc") and no rank column: it is read as a list of full professors.
# Usage: Rscript R/21_compare_head.R
# Env: TABLES_OUT (default data/interim/tables_trial), TABLES_YEAR (default 2026), HAND_FILE.
# Output: output/head_comparison/ (matched, hand_only, ours_only, summary_by_inst, institutions).
library(tidyverse)
library(readxl)
library(stringdist)
source("R/registry.R")   # norm_text()

out_dir <- Sys.getenv("TABLES_OUT", "data/interim/tables_trial")
yr <- as.integer(Sys.getenv("TABLES_YEAR", "2026"))
hand_file <- Sys.getenv("HAND_FILE", "data/Head - AAU Database.xlsx")
res_dir <- "output/head_comparison"; dir.create(res_dir, recursive = TRUE, showWarnings = FALSE)

# University labels in the hand file -> inst_id
uni_map <- c("Arizona State" = "asu", "Boston U" = "bu", "Brandeis" = "brandeis", "Brown" = "brown", "CU Boulder" = "cuboulder",
  "Case Western" = "cwru", "Columbia" = "columbia", "Cornell" = "cornell", "Dartmouth" = "dartmouth", "Duke" = "duke",
  "Emory" = "emory", "George Washington" = "gwu", "Georgia Tech" = "gatech", "Harvard" = "harvard", "Indiana University" = "indiana",
  "Johns Hopkins" = "jhu", "MIT" = "mit", "McGill" = "mcgill", "Michigan State University" = "msu", "NYU" = "nyu",
  "Northwestern" = "northwestern", "Notre Dame" = "notredame", "Ohio State University" = "osu", "Penn State" = "psu",
  "Princeton" = "princeton", "Rice" = "rice", "Rutgers" = "rutgers", "SUNY Buffalo" = "buffalo", "Stanford" = "stanford",
  "Stony Brook" = "stonybrook", "Texas A&M" = "tamu", "Tufts" = "tufts", "Tulane" = "tulane", "U Arizona" = "uarizona",
  "U Chicago" = "uchicago", "U Florida" = "ufl", "U Iowa" = "uiowa", "U Kansas" = "ku", "U Maryland" = "umd", "U Miami" = "miami",
  "U Michigan" = "umich", "U Minnesota" = "umn", "U Missouri" = "mizzou", "U North Carolina" = "unc", "U Oregon" = "uoregon",
  "U Penn" = "upenn", "U Pittsburgh" = "pitt", "U South Florida" = "usf", "U Southern California" = "usc", "U Toronto" = "utoronto",
  "U Utah" = "utah", "U Virginia" = "uva", "U Washington" = "uw", "U Wisconsin" = "wisc", "UC Berkeley" = "ucberkeley",
  "UC Davis" = "ucdavis", "UC Irvine" = "ucirvine", "UC Riverside" = "ucriverside", "UC San Diego" = "ucsd",
  "UC Santa Barbara" = "ucsb", "UC Santa Cruz" = "ucsc", "UCLA" = "ucla", "UI Urbana-Champaign" = "uiuc",
  "UT Austin" = "utaustin", "Vanderbilt" = "vanderbilt", "Washington U" = "wustl", "Yale" = "yale")

tok1 <- \(x) str_extract(norm_text(x), "^[a-z]+"); tokn <- \(x) str_extract(norm_text(x), "[a-z]+$")
hand <- read_excel(hand_file, col_types = "text") |>
  transmute(hand_row = row_number() + 1L, hand_name = Name, university = University, hand_areas = Areas, hand_note = Note,
            inst_id = unname(uni_map[University]),
            last = str_trim(str_extract(Name, "^[^,]+")), first = str_trim(str_extract(Name, "(?<=,).*$")),
            first_tok = tok1(first), last_tok = tokn(last))
stopifnot(!anyNA(hand$inst_id))

snap <- read_csv(file.path(out_dir, "snapshots.csv"), show_col_types = FALSE, col_types = cols(.default = "c", year = "i", included = "l")) |>
  filter(year == yr)
ppl <- read_csv(file.path(out_dir, "people.csv"), show_col_types = FALSE, col_types = cols(.default = "c"))
ours <- snap |> inner_join(select(ppl, person_id, name_first, name_middle, name_last), by = "person_id") |>
  mutate(our_name = paste(name_first, name_last), first_tok = tok1(name_first), last_tok = tokn(name_last),
         given_toks = map2_chr(name_first, name_middle, \(a, b) paste(norm_text(paste(a, b)), collapse = " "))) |>
  select(person_id, inst_id, our_name, given_toks, first_tok, last_tok, our_rank = rank, appointment_type, included, title_raw, listing_section, review_flag)

# ---- institution coverage ----
cfg <- read_csv("data/seeds/institutions_seed.csv", show_col_types = FALSE) |> select(inst_id, url_status)
coverage <- tibble(inst_id = sort(unique(c(hand$inst_id, ours$inst_id)))) |>
  mutate(in_hand = inst_id %in% hand$inst_id, in_ours = inst_id %in% ours$inst_id) |> left_join(cfg, by = "inst_id") |>
  mutate(status = case_when(in_hand & in_ours ~ "compared",
                            in_hand & url_status == "url_confirmed_by_hand_blocked" ~ "not compared: hand-collect site (blocked)",
                            in_hand & url_status == "no_soc_dept" ~ "not compared: no sociology department",
                            in_hand ~ "not compared: no data in our tables",
                            TRUE ~ "ours only (not in hand file)"))
compared <- coverage$inst_id[coverage$status == "compared"]

# ---- name matching within each institution, one-to-one, in tiers ----
match_inst <- function(h, o) {
  h$our_idx <- NA_integer_; h$tier <- NA_character_
  claim <- \(h, o, key_h, key_o, tier) {
    for (i in which(is.na(h$our_idx) & !is.na(key_h))) {
      cand <- which(key_o == key_h[i] & !seq_len(nrow(o)) %in% h$our_idx[!is.na(h$our_idx)])
      if (length(cand) >= 1) { h$our_idx[i] <- cand[1]; h$tier[i] <- if (length(cand) > 1) paste0(tier, " (ambiguous)") else tier }
    }
    h
  }
  h <- claim(h, o, paste(h$first_tok, h$last_tok), paste(o$first_tok, o$last_tok), "exact")
  h <- claim(h, o, paste(str_sub(h$first_tok, 1, 1), h$last_tok), paste(str_sub(o$first_tok, 1, 1), o$last_tok), "first initial + last")
  # same surname and the hand file's given name is any given-name token of ours (e.g., a middle name in use)
  for (i in which(is.na(h$our_idx) & !is.na(h$first_tok))) {
    free <- setdiff(seq_len(nrow(o)), h$our_idx[!is.na(h$our_idx)])
    cand <- free[o$last_tok[free] == h$last_tok[i] & map_lgl(o$given_toks[free], \(g) h$first_tok[i] %in% str_split_1(g, " "))]
    if (length(cand)) { h$our_idx[i] <- cand[1]; h$tier[i] <- "last name + any given name (check)" }
  }
  # similar surname spelling with the same first initial (e.g., Owen / Owens)
  for (i in which(is.na(h$our_idx) & !is.na(h$first_tok))) {
    free <- setdiff(seq_len(nrow(o)), h$our_idx[!is.na(h$our_idx)])
    cand <- free[str_sub(o$first_tok[free], 1, 1) == str_sub(h$first_tok[i], 1, 1) & stringsim(o$last_tok[free], h$last_tok[i], method = "jw", p = 0.1) >= 0.93]
    if (length(cand)) { h$our_idx[i] <- cand[1]; h$tier[i] <- "similar surname + first initial (check)" }
  }
  for (i in which(is.na(h$our_idx))) {     # fuzzy: close full-name spelling, candidate only
    free <- setdiff(seq_len(nrow(o)), h$our_idx[!is.na(h$our_idx)]); if (!length(free)) next
    sim <- stringsim(paste(h$first_tok[i], h$last_tok[i]), paste(o$first_tok[free], o$last_tok[free]), method = "jw", p = 0.1)
    if (max(sim) >= 0.90) { h$our_idx[i] <- free[which.max(sim)]; h$tier[i] <- sprintf("fuzzy %.2f (check)", max(sim)) }
  }
  h
}
hand_c <- hand |> filter(inst_id %in% compared)
res <- map(compared, \(id) {
  h <- filter(hand_c, inst_id == id); o <- filter(ours, inst_id == id)
  h <- match_inst(h, o)
  list(h = bind_cols(h, o[h$our_idx, setdiff(names(o), c("inst_id", "first_tok", "last_tok", "given_toks"))]),
       o_unmatched = o[setdiff(seq_len(nrow(o)), h$our_idx[!is.na(h$our_idx)]), ])
})
h_all <- map(res, "h") |> list_rbind()
o_un <- map(res, "o_unmatched") |> list_rbind()

# Where a hand-file name was not found at its institution: is it at another institution in ours?
elsewhere <- ours |> mutate(k = paste(first_tok, last_tok)) |> group_by(k) |> summarise(also_in_ours_at = paste(sort(unique(inst_id)), collapse = ";"), .groups = "drop")
h_all <- h_all |> mutate(k = paste(first_tok, last_tok)) |> left_join(elsewhere, by = "k") |> select(-k) |>
  mutate(also_in_ours_at = if_else(is.na(tier) & !is.na(also_in_ours_at) & also_in_ours_at != inst_id, also_in_ours_at, NA_character_))

h_all <- h_all |> mutate(
  outcome = case_when(
    is.na(tier) ~ "hand only: not in our data for this institution",
    included %in% TRUE ~ "agree: in both, ours = included full professor",
    is.na(included) ~ "in both, ours undecided (appointment type unknown)",
    TRUE ~ paste0("in both, ours excludes: rank=", our_rank, ", appointment=", appointment_type)),
  expected = case_when(!is.na(hand_note) & str_detect(hand_note, "emerit") ~ "hand note: emeritus",
                       !is.na(hand_note) & hand_note == "not soc" ~ "hand note: not sociology", TRUE ~ NA_character_))

o_un <- o_un |> filter(included %in% TRUE | is.na(included)) |>
  mutate(outcome = if_else(included %in% TRUE, "ours only: included full professor not in hand file", "ours only: undecided (appointment type unknown)"))

write_csv(h_all |> select(inst_id, hand_name, university, hand_note, outcome, expected, tier, our_name, our_rank, appointment_type, included, title_raw,
                          listing_section, also_in_ours_at, person_id, hand_row), file.path(res_dir, "hand_vs_ours.csv"))
write_csv(o_un |> select(inst_id, our_name, our_rank, appointment_type, included, title_raw, listing_section, outcome, person_id), file.path(res_dir, "ours_only.csv"))
write_csv(coverage, file.path(res_dir, "institutions.csv"))

summ <- full_join(
  h_all |> group_by(inst_id) |> summarise(hand = n(), agree = sum(str_starts(outcome, "agree")), hand_only = sum(str_starts(outcome, "hand only")),
                                           ours_excludes = sum(str_starts(outcome, "in both, ours excludes")), ours_undecided = sum(str_starts(outcome, "in both, ours undecided"))),
  o_un |> group_by(inst_id) |> summarise(ours_only = sum(included %in% TRUE), ours_only_undecided = sum(is.na(included))), by = "inst_id") |>
  mutate(across(where(is.numeric), \(x) coalesce(x, 0L))) |> arrange(inst_id)
write_csv(summ, file.path(res_dir, "summary_by_inst.csv"))

cat("Institutions: hand file", n_distinct(hand$inst_id), "| compared", length(compared), "\n")
print(count(coverage, status))
cat("\nHand rows in compared institutions:", nrow(h_all), "\n"); print(count(h_all, outcome, sort = TRUE), width = 140)
cat("\nOurs only:", sum(o_un$included %in% TRUE), "included,", sum(is.na(o_un$included)), "undecided\n")
cat("\nName-match tiers:\n"); print(count(h_all, tier))
print(summ, n = 60)
