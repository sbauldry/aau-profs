# Run configuration: one place that decides where every stage reads and writes (trial or production).
# Usage: set RUN=production in the environment (default is trial), e.g.  RUN=production Rscript R/14_build_tables.R
# Production writes under data/interim/<year>/ and data/final/ and uses its own API usage log and budget cap, so
# trial files, trial person_ids and trial spend never mix with production (production plan, 2026-10-21).
# AAU_RUN_ROOT (default empty) moves every path under another folder; it exists for dry runs and tests only.
library(tidyverse)

run_mode <- function() {
  m <- Sys.getenv("RUN", "trial")
  if (!m %in% c("trial", "production")) stop("RUN must be 'trial' or 'production', not '", m, "'")
  m
}

run_paths <- function(mode = run_mode(), root = Sys.getenv("AAU_RUN_ROOT", "")) {
  yr <- as.integer(Sys.getenv("TABLES_YEAR", "2026"))
  at <- \(p) if (nzchar(root)) file.path(root, p) else p
  if (mode == "trial") {
    p <- list(raw_year = "trial", scrape_dir = "data/interim/scrape_trial", roster_dir = "data/interim/extract_trial",
              sibling_dir = "data/interim/extract_trial_siblings", profile_dir = "data/interim/profiles_trial",
              tables_dir = "data/interim/tables_trial", usage_log = "logs/api_usage.csv", run_log = "logs/run_trial.md", budget = 20)
  } else {
    base <- file.path("data/interim", yr)
    p <- list(raw_year = as.character(yr), scrape_dir = file.path(base, "scrape"), roster_dir = file.path(base, "rosters"),
              sibling_dir = file.path(base, "siblings"), profile_dir = file.path(base, "profiles"),
              tables_dir = "data/final", usage_log = sprintf("logs/api_usage_%d.csv", yr), run_log = sprintf("logs/run_%d.md", yr), budget = 25)
  }
  p[c("scrape_dir", "roster_dir", "sibling_dir", "profile_dir", "tables_dir", "usage_log", "run_log")] <-
    map(p[c("scrape_dir", "roster_dir", "sibling_dir", "profile_dir", "tables_dir", "usage_log", "run_log")], at)
  p$mode <- mode; p$year <- yr; p$raw_html <- at("data/raw_html"); p$hand_dir <- at("data/hand_collected"); p$root <- root
  # explicit overrides stay possible for single stages, but never into the wrong run's area
  if (nzchar(Sys.getenv("TABLES_OUT"))) p$tables_dir <- Sys.getenv("TABLES_OUT")
  if (nzchar(Sys.getenv("TABLES_IN"))) p$profile_dir <- Sys.getenv("TABLES_IN")
  if (nzchar(Sys.getenv("BUDGET_USD"))) p$budget <- as.numeric(Sys.getenv("BUDGET_USD"))
  assert_run_safe(p)
  p
}

# Refuse configurations that could mix trial and production data.
assert_run_safe <- function(p) {
  dirs <- unlist(p[c("scrape_dir", "roster_dir", "sibling_dir", "profile_dir", "tables_dir")])
  is_final <- \(d) basename(d) == "final"
  if (p$mode == "production") {
    bad <- dirs[str_detect(dirs, "trial")]
    if (length(bad)) stop("production run points at trial paths: ", paste(bad, collapse = ", "))
    if (!is_final(p$tables_dir) && !nzchar(p$root)) stop("production tables must go to data/final (got ", p$tables_dir, ")")
  } else {
    if (is_final(p$tables_dir)) stop("a trial run must not write to data/final")
  }
  invisible(TRUE)
}

# Dollars spent so far in this run's usage log (all steps, or one step).
run_spent <- function(p = run_paths(), step = NULL) {
  if (!file.exists(p$usage_log)) return(0)
  u <- readr::read_csv(p$usage_log, show_col_types = FALSE)
  if (!nrow(u)) return(0)
  price <- tribble(~model, ~pin, ~pout, ~pcache, "claude-sonnet-5-5", 2, 10, 0.2, "claude-opus-5-5", 4, 20, 0.2)
  u <- left_join(u, price, by = "model") |> mutate(usd = ((input - cached_input) * pin + cached_input * pcache + output * pout) / 1e6)
  sum(u$usd[is.null(step) | u$step %in% step], na.rm = TRUE)
}

# Append a line to the run record (logs/run_<year>.md): stage, models, prompt versions, counts, spend so far.
run_log <- function(stage, counts = list(), note = NULL, p = run_paths()) {
  dir.create(dirname(p$run_log), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(p$run_log))
    writeLines(c(sprintf("# Run record, %s (%s)", p$year, p$mode), "", "| time | stage | counts | spent so far (USD) | note |", "|---|---|---|---|---|"), p$run_log)
  cnt <- if (length(counts)) paste(names(counts), unlist(counts), sep = "=", collapse = "; ") else ""
  cat(sprintf("| %s | %s | %s | %.2f | %s |\n", format(Sys.time(), "%Y-%m-%d %H:%M"), stage, cnt, run_spent(p), note %||% ""),
      file = p$run_log, append = TRUE)
  invisible(p$run_log)
}

# Integrity checks on a tables folder (run after every table build; stops with a message on any failure).
check_tables_integrity <- function(dir) {
  rd <- \(f) readr::read_csv(file.path(dir, f), show_col_types = FALSE, col_types = readr::cols(.default = "c"))
  reg <- rd("person_id_registry.csv"); ppl <- rd("people.csv"); snap <- rd("snapshots.csv")
  fail <- character()
  if (anyDuplicated(reg$person_id)) fail <- c(fail, "registry has duplicate person_ids")
  if (!identical(reg$person_id, sprintf("p%06d", seq_len(nrow(reg))))) fail <- c(fail, "registry is not sequential from p000001")
  if (anyDuplicated(ppl$person_id)) fail <- c(fail, "people has duplicate person_ids")
  if (!all(ppl$person_id %in% reg$person_id)) fail <- c(fail, "people has person_ids missing from the registry")
  if (!all(snap$person_id %in% ppl$person_id)) fail <- c(fail, "snapshots has person_ids missing from people")
  if (anyDuplicated(snap[c("person_id", "year", "inst_id")])) fail <- c(fail, "snapshots key (person_id, year, inst_id) is not unique")
  if (length(fail)) stop("table integrity check failed in ", dir, ":\n  ", paste(fail, collapse = "\n  "))
  invisible(TRUE)
}
