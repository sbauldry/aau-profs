# AAU member list: parse a hand-saved copy of AAU's "members by year of entry" page and compare it with the previous list.
# AAU's page blocked our scraper on 2026-10-21 (robots-aware, identified user-agent), so by codebook §10 it is saved by
# hand: open the page in your own browser and save it (see data/hand_collected/README.md) as
#   data/hand_collected/aau_members__<YYYY-MM-DD>.{csv,txt,html}      (the date is the retrieval date)
library(tidyverse)
library(stringdist)

aau_source_url <- "https://www.aau.edu/resource-library/aau-member-universities-by-year-of-entry"
member_cols <- c("inst_name", "sector", "entry_year", "country", "source_url", "retrieved")

norm_member <- \(x) x |> stringi::stri_trans_general("Latin-ASCII") |> str_to_lower() |> str_replace_all("&", " and ") |>
  str_remove_all("[^a-z ]") |> str_replace_all("\\bthe\\b|\\buniversity\\b|\\bof\\b|\\bat\\b|\\bin\\b|\\band\\b", " ") |> str_squish()

# Lightly normalized form (keeps "university"), so a typo in that word still matches.
norm_loose <- \(x) x |> stringi::stri_trans_general("Latin-ASCII") |> str_to_lower() |> str_remove_all("[^a-z ]") |> str_squish()

# --- parsing: three accepted shapes of the saved page ------------------------------------------------------------
parse_member_file <- function(path) {
  ext <- str_to_lower(tools::file_ext(path))
  raw <- switch(ext,
    csv = read_csv(path, show_col_types = FALSE, col_types = cols(.default = "c")),
    txt = parse_member_text(read_lines(path)),
    html = , htm = parse_member_html(path),
    stop("unsupported file type '.", ext, "' (use .csv, .txt or .html)"))
  if (!all(c("inst_name", "entry_year") %in% names(raw))) stop("the parsed list needs inst_name and entry_year columns; found: ", paste(names(raw), collapse = ", "))
  raw |> mutate(inst_name = str_squish(str_remove_all(inst_name, "[*†‡]|\\[\\d+\\]")), entry_year = as.integer(str_extract(entry_year, "\\d{4}"))) |>
    filter(!is.na(inst_name), nzchar(inst_name))
}

# Text: one member per line with a four-digit year at the start or end (separator: tab, comma, dash, parentheses, spaces).
parse_member_text <- function(lines) {
  y <- "(?:18|19|20)\\d{2}"
  m <- tibble(line = str_squish(lines)) |> filter(nzchar(line)) |>
    mutate(year_end = str_match(line, paste0("^(.*?)[\\s,;\\-–—(]+(", y, ")\\)?$")),
           year_start = str_match(line, paste0("^(", y, ")[\\s,;\\-–—):]+(.*)$")))
  tibble(inst_name = coalesce(m$year_end[, 2], m$year_start[, 3]), entry_year = coalesce(m$year_end[, 3], m$year_start[, 2])) |>
    filter(!is.na(inst_name), !is.na(entry_year))
}

# HTML: a table with a name column and a year column; otherwise list items "Name (year)".
parse_member_html <- function(path) {
  doc <- rvest::read_html(path)
  for (t in rvest::html_table(doc, convert = FALSE)) {
    nm <- names(t); name_col <- nm[str_detect(str_to_lower(nm), "universit|institution|member|name")][1]
    year_col <- nm[str_detect(str_to_lower(nm), "year|entry|joined|admitted")][1]
    if (!is.na(name_col) && !is.na(year_col)) return(tibble(inst_name = t[[name_col]], entry_year = t[[year_col]],
      sector = if ("Sector" %in% nm) t[["Sector"]] else NA_character_, country = if ("Country" %in% nm) t[["Country"]] else NA_character_) |>
      select(where(~ !all(is.na(.x)))))
  }
  parse_member_text(rvest::html_text2(rvest::html_elements(doc, "li, p, tr")))
}

# --- assembling and checking --------------------------------------------------------------------------------------
# Fill sector and country from the previous list where the member is already known; anything new is NA and reported.
build_member_list <- function(parsed, previous, retrieved) {
  prev <- previous |> mutate(key = norm_member(inst_name)) |> distinct(key, .keep_all = TRUE)
  parsed |> mutate(key = norm_member(inst_name)) |> distinct(key, .keep_all = TRUE) |>
    left_join(select(prev, key, sector_prev = sector, country_prev = country), by = "key") |>
    mutate(sector = coalesce(if ("sector" %in% names(parsed)) .data$sector else NA_character_, sector_prev),
           country = coalesce(if ("country" %in% names(parsed)) .data$country else NA_character_, country_prev),
           source_url = aau_source_url, retrieved = as.character(as.Date(retrieved))) |>
    select(all_of(member_cols), key)
}

# Compare with the previous list: added, removed, renamed (close names), and year changes.
diff_members <- function(current, previous) {
  cur <- current |> mutate(key = norm_member(inst_name)); prv <- previous |> mutate(key = norm_member(inst_name))
  added <- anti_join(cur, prv, by = "key"); removed <- anti_join(prv, cur, by = "key")
  renamed <- if (nrow(added) && nrow(removed)) crossing(new = added$inst_name, old = removed$inst_name) |>
    mutate(sim = pmax(stringsim(norm_member(new), norm_member(old), method = "jw", p = 0.1),
                                       stringsim(norm_loose(new), norm_loose(old), method = "jw", p = 0.1))) |> filter(sim >= 0.9) else tibble(new = character(), old = character(), sim = numeric())
  year_changed <- inner_join(cur, prv, by = "key", suffix = c("", "_prev")) |> filter(entry_year != entry_year_prev) |> select(inst_name, entry_year, entry_year_prev)
  list(added = added, removed = removed, renamed_candidates = renamed, year_changed = year_changed, n_current = nrow(cur), n_previous = nrow(prv))
}

# Sanity limits: a wrong parse should stop here, not flow into the seed table.
check_member_list <- function(lst, lo = 50, hi = 110) {
  problems <- character()
  if (nrow(lst) < lo || nrow(lst) > hi) problems <- c(problems, sprintf("%d members parsed (expected %d to %d)", nrow(lst), lo, hi))
  if (anyNA(lst$entry_year) || any(lst$entry_year < 1900 | lst$entry_year > 2030, na.rm = TRUE)) problems <- c(problems, "some entry years are missing or out of range")
  if (anyDuplicated(lst$inst_name)) problems <- c(problems, "duplicate institution names")
  if (length(problems)) stop("member list check failed:\n  ", paste(problems, collapse = "\n  "))
  invisible(TRUE)
}
