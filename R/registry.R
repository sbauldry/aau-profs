# person_id registry and identity matching (codebook.md §3.2a and §6).
# Only this code mints IDs, and it writes the registry before any table uses a new ID.
# Matching is conservative: ORCID (rule 1) and exact normalized name within an institution
# (rule 2) link automatically; fuzzy (rule 3) and cross-institution (rule 4) matches are only
# candidates for hand review and never link.
library(tidyverse)
library(stringdist)

registry_cols <- c("person_id", "minted_year", "status", "merged_into", "note")

registry_read <- function(file) {
  if (!file.exists(file)) return(tibble(person_id = character(), minted_year = integer(), status = character(),
                                        merged_into = character(), note = character()))
  read_csv(file, show_col_types = FALSE, col_types = cols(.default = "c", minted_year = "i"))
}

# Mint `n` new IDs: the next ID is the maximum ever issued (retired included) plus one.
# Writes the registry before returning the IDs.
registry_mint <- function(n, year, file, note = NA_character_) {
  if (n == 0) return(character())
  reg <- registry_read(file)
  last <- if (nrow(reg) == 0) 0L else max(as.integer(str_sub(reg$person_id, 2)))
  ids <- sprintf("p%06d", last + seq_len(n))
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  reg |> bind_rows(tibble(person_id = ids, minted_year = as.integer(year), status = "active",
                          merged_into = NA_character_, note = note)) |> write_csv(file)
  ids
}

# Lowercase, diacritics stripped, letters only.
norm_text <- function(x) {
  x |> stringi::stri_trans_general("Latin-ASCII") |> str_to_lower() |>
    str_replace_all("[^a-z ]", " ") |> str_squish()
}

# Matching key: first token of the first name plus last token of the last name (middle names and
# suffixes dropped; falls back to `name_raw` when the extractor left a part empty). A multi-part
# surname therefore keys the same way whether or not the extractor split it.
name_key <- function(first, last, raw) {
  tok <- \(x, which) {
    t <- str_split(norm_text(coalesce(x, "")), " ")
    map_chr(t, \(v) { v <- v[v != ""]; if (length(v) == 0) NA_character_ else if (which == "first") v[1] else v[length(v)] })
  }
  rawclean <- str_remove(coalesce(raw, ""), ",.*$")
  f <- coalesce(tok(first, "first"), tok(rawclean, "first"))
  l <- coalesce(tok(last, "last"), tok(rawclean, "last"))
  if_else(is.na(f) | is.na(l), NA_character_, paste(f, l))
}

# Share of area words in common (any shared word of 5+ letters counts as overlap).
areas_overlap <- function(a, b) {
  w <- \(x) str_split(norm_text(coalesce(x, "")), " ")[[1]] |> keep(\(t) nchar(t) >= 5) |> unique()
  length(intersect(w(a), w(b))) > 0
}

# Assign `person_id` to the current year's records.
#   cur: one row per person at one institution, columns inst_id, name_key, orcid, name_first, name_last,
#        phd_inst, phd_year, areas_raw
#   prior: existing snapshots (any year, including this one, so a rerun reuses IDs) with the same
#          columns plus person_id
# Returns `cur` with person_id, match_rule ("orcid", "name", "new"), cand_note (candidate text or NA)
# and cand_flag. A key that matches more than one prior person is ambiguous: no link, flagged.
assign_person_ids <- function(cur, prior, year, registry_file) {
  cur <- cur |> mutate(person_id = NA_character_, match_rule = NA_character_, cand_note = NA_character_)
  prior_u <- prior |> distinct(person_id, inst_id, name_key, orcid, name_first, name_last, phd_inst, phd_year, areas_raw)

  # rule 1: ORCID, definitive
  by_orcid <- prior_u |> filter(!is.na(orcid)) |> distinct(orcid, person_id) |> group_by(orcid) |> filter(n() == 1) |> ungroup()
  m1 <- match(cur$orcid, by_orcid$orcid)
  hit <- !is.na(cur$orcid) & !is.na(m1)
  cur$person_id[hit] <- by_orcid$person_id[m1[hit]]; cur$match_rule[hit] <- "orcid"

  # rule 2: same institution + exact normalized name; unique prior person only
  uniq <- prior_u |> filter(!is.na(name_key)) |> group_by(inst_id, name_key) |>
    summarise(n_ids = n_distinct(person_id), person_id = first(person_id), .groups = "drop")
  j <- cur |> select(inst_id, name_key) |> left_join(uniq, by = c("inst_id", "name_key"))
  amb <- !is.na(j$n_ids) & j$n_ids > 1
  hit <- is.na(cur$person_id) & !is.na(j$n_ids) & j$n_ids == 1
  cur$person_id[hit] <- j$person_id[hit]; cur$match_rule[hit] <- "name"
  cur$cand_note[amb & is.na(cur$person_id)] <- "ambiguous: name matches more than one prior person_id at this institution"

  # a person_id may be claimed by one current record only (a duplicate means two records for one person)
  dup <- !is.na(cur$person_id) & duplicated(cur$person_id)
  cur$person_id[dup] <- NA_character_; cur$match_rule[dup] <- NA_character_
  cur$cand_note[dup] <- "duplicate: another record this year already matched the same person_id"

  # rules 3 and 4: candidates only, evaluated for records that stay unmatched
  todo <- which(is.na(cur$person_id))
  for (i in todo) {
    r <- cur[i, ]; notes <- character()
    same <- prior_u |> filter(inst_id == r$inst_id, !is.na(name_key), !is.na(r$name_key))
    if (nrow(same)) {
      sim <- stringsim(r$name_key, same$name_key, method = "jw", p = 0.1)
      for (k in which(sim >= 0.92)) {
        if (areas_overlap(r$areas_raw, same$areas_raw[k]))
          notes <- c(notes, sprintf("fuzzy name candidate %s (%s, similarity %.2f)", same$person_id[k], same$name_key[k], sim[k]))
      }
    }
    other <- prior_u |> filter(inst_id != r$inst_id, name_key == r$name_key, !is.na(r$name_key),
                               !is.na(phd_inst), !is.na(phd_year), phd_inst == r$phd_inst, phd_year == r$phd_year)
    if (nrow(other)) notes <- c(notes, sprintf("possible move from %s: candidate %s", other$inst_id[1], other$person_id[1]))
    if (length(notes)) cur$cand_note[i] <- paste(c(na.omit(cur$cand_note[i]), notes), collapse = "; ")
  }

  # rule 5: everything still unmatched is new; mint once, registry first
  need <- which(is.na(cur$person_id))
  cur$person_id[need] <- registry_mint(length(need), year, registry_file)
  cur$match_rule[need] <- "new"
  cur
}
