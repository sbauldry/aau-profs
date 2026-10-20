# Prompt freezing (codebook.md §9). A prompt file is never edited after it has been used in a production run.
# freeze_prompt() marks the file FROZEN and records its SHA-256 and the pinned model in logs/prompt_freeze_<year>.md;
# assert_prompt_frozen() is called by load_system_prompt() in production and stops if the file is not frozen,
# was edited since, or the pinned model differs from the recorded one.
library(tidyverse)

freeze_record <- \(year = 2026L) sprintf("logs/prompt_freeze_%d.md", year)
file_sha256 <- \(f) digest::digest(file = f, algo = "sha256", serialize = FALSE)

freeze_prompt <- function(file, model, codebook_version, year = 2026L, record = freeze_record(year)) {
  txt <- read_file(file)
  if (str_detect(txt, "(?m)^status: FROZEN")) stop(file, " is already frozen")
  if (!str_detect(txt, "(?m)^status:")) stop(file, " has no status line in its header")
  txt <- str_replace(txt, "(?m)^status:.*$", sprintf("status: FROZEN %s (first used in the %d production run; any change is a new version file and a codebook section 8 entry)", Sys.Date(), year))
  write_file(txt, file)
  ver <- str_match(txt, "(?m)^version: (\\S+)")[, 2]
  if (!file.exists(record)) {
    dir.create(dirname(record), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(sprintf("# Prompt freeze record, %d", year), "", "| file | version | sha256 | pinned model | codebook | frozen on |", "|---|---|---|---|---|---|"), record)
  }
  cat(sprintf("| %s | %s | %s | %s | v%s | %s |\n", file, ver, file_sha256(file), model, codebook_version, Sys.Date()), file = record, append = TRUE)
  invisible(file_sha256(file))
}

assert_prompt_frozen <- function(file, model = NULL, record = freeze_record(as.integer(Sys.getenv("TABLES_YEAR", "2026")))) {
  if (!str_detect(read_file(file), "(?m)^status: FROZEN")) stop("production needs a frozen prompt: ", file, " is not marked FROZEN (see R/freeze.R)")
  if (!file.exists(record)) stop("no prompt freeze record at ", record)
  rec <- read_lines(record) |> keep(\(l) str_starts(l, fixed(paste0("| ", file, " |"))))
  if (!length(rec)) stop(file, " is not in the freeze record ", record)
  cols <- str_split_1(last(rec), "\\s*\\|\\s*")
  if (!identical(cols[4], file_sha256(file))) stop(file, " was edited after it was frozen (hash differs). Create a new version file instead (codebook section 9).")
  if (!is.null(model) && !identical(cols[5], model)) stop("pinned model for ", file, " is ", cols[5], " in the freeze record but ", model, " in the code")
  invisible(TRUE)
}
