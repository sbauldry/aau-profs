# Load hand-collected page text (data/hand_collected/<inst_id>__<list_type>.txt; see its README) and run it through
# the same extraction as scraped pages. Output matches the scraped stage: the main list goes to the roster folder as
# <inst_id>.csv, sibling lists to the sibling folder as <inst_id>__<type>__<hash>.csv, so script 13 and the rest of
# the pipeline pick them up unchanged.
library(tidyverse)
source("R/scrape.R"); source("R/site_config.R"); source("R/extract.R")

list_types <- c("faculty", "emeriti", "affiliated", "joint", "adjunct", "visiting", "nontenure")

# First line "# url: <URL>  date: <YYYY-MM-DD>", then the pasted page text.
parse_hand_file <- function(path) {
  m <- str_match(basename(path), "^([a-z0-9]+)__([a-z]+)\\.txt$")
  if (is.na(m[1, 1])) stop("hand-collected file names must be <inst_id>__<list_type>.txt: ", basename(path))
  if (!m[1, 3] %in% list_types) stop("unknown list type '", m[1, 3], "' in ", basename(path), " (use one of: ", paste(list_types, collapse = ", "), ")")
  lines <- read_lines(path)
  hdr <- str_match(lines[[1]], "^#\\s*url:\\s*(\\S+)\\s+date:\\s*(\\d{4}-\\d{2}-\\d{2})")
  if (is.na(hdr[1, 1])) stop("first line of ", basename(path), " must be '# url: <URL>  date: <YYYY-MM-DD>'")
  list(inst_id = m[1, 2], list_type = m[1, 3], url = hdr[1, 2], date = as.Date(hdr[1, 3]), text = paste(lines[-1], collapse = "\n"))
}

# Extract one file. `extractor` is injectable so tests need no API.
extract_hand_file <- function(path, cfg, sp, p = run_paths(), extractor = extract_page, force = FALSE) {
  h <- parse_hand_file(path)
  row <- filter(cfg, inst_id == h$inst_id)
  if (!nrow(row)) stop("unknown inst_id '", h$inst_id, "' in ", basename(path))
  if (!nzchar(str_squish(h$text))) stop(basename(path), " has no page text")
  out <- if (h$list_type == "faculty") file.path(p$roster_dir, paste0(h$inst_id, ".csv"))
         else file.path(p$sibling_dir, paste0(h$inst_id, "__", h$list_type, "__", str_sub(digest::digest(h$url, algo = "md5", serialize = FALSE), 1, 8), ".csv"))
  if (file.exists(out) && !force) return(tibble(file = basename(path), inst_id = h$inst_id, list_type = h$list_type, records = NA_integer_, status = "skipped (output exists)"))
  txt <- if (h$list_type == "faculty") h$text else paste0("Page heading: ", h$list_type, " list\n\n", h$text)
  res <- imap(chunk_text(txt, max_chars = 9000), \(t, i) extractor(row$inst_name, h$url, t, retrieved = h$date, system_prompt = sp)) |> list_rbind() |>
    mutate(inst_id = h$inst_id, .before = 1)
  if (h$list_type != "faculty") res <- mutate(res, list_type = h$list_type, list_label = paste(h$list_type, "list (hand-collected)"), .after = inst_id)
  res <- dedupe_roster(res)
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  write_csv(res, out)
  tibble(file = basename(path), inst_id = h$inst_id, list_type = h$list_type, records = nrow(res), status = "extracted")
}
