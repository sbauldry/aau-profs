# Tests for the Phase 0 infrastructure: run configuration, trial/production separation, prompt freezing,
# table integrity checks, run records, and the hand-collected loader. No API calls. Usage: Rscript R/29_test_run_infrastructure.R
suppressMessages(library(tidyverse))
source("R/run_config.R"); source("R/freeze.R"); source("R/hand_collected.R"); source("R/assemble.R")
expect_error <- \(expr, pattern) { r <- tryCatch({ expr; NULL }, error = \(e) conditionMessage(e)); stopifnot(!is.null(r), str_detect(r, pattern)) }
tmp <- file.path(tempdir(), "infra"); dir.create(tmp)

# --- run paths: trial and production never share a folder, log, or budget
tp <- run_paths("trial", ""); pp <- run_paths("production", "")
stopifnot(tp$tables_dir == "data/interim/tables_trial", pp$tables_dir == "data/final", pp$usage_log != tp$usage_log, pp$budget == 25,
          !any(str_detect(unlist(pp[c("scrape_dir", "roster_dir", "sibling_dir", "profile_dir", "tables_dir", "usage_log")]), "trial")),
          pp$roster_dir == "data/interim/2026/rosters", pp$run_log == "logs/run_2026.md")
Sys.setenv(RUN = "bogus"); expect_error(run_mode(), "RUN must be"); Sys.unsetenv("RUN")
Sys.setenv(TABLES_OUT = "data/final"); expect_error(run_paths("trial", ""), "must not write to data/final"); Sys.unsetenv("TABLES_OUT")
Sys.setenv(TABLES_IN = "data/interim/profiles_trial"); expect_error(run_paths("production", ""), "trial paths"); Sys.unsetenv("TABLES_IN")
Sys.setenv(TABLES_OUT = "somewhere/else"); expect_error(run_paths("production", ""), "data/final"); Sys.unsetenv("TABLES_OUT")
rr <- run_paths("production", file.path(tmp, "root")); stopifnot(str_starts(rr$tables_dir, tmp), str_starts(rr$raw_html, tmp))   # dry-run root moves everything

# --- spend: counted per run's own usage log
dir.create(file.path(tmp, "logs")); ul <- file.path(tmp, "logs", "u.csv")
write_csv(tibble(timestamp = "t", step = c("extract", "code"), model = c("claude-sonnet-5-5", "claude-opus-5-5"), prompt_ver = "v1", source_url = "x",
                 input = c(1e6, 1e6), output = c(1e5, 1e5), cached_input = 0), ul)
stopifnot(isTRUE(all.equal(run_spent(list(usage_log = ul)), (2 + 1 + 4 + 2))), isTRUE(all.equal(run_spent(list(usage_log = ul), step = "code"), 6)),
          run_spent(list(usage_log = file.path(tmp, "none.csv"))) == 0)

# --- run record
lg <- list(run_log = file.path(tmp, "logs", "run.md"), usage_log = ul, year = 2026, mode = "production")
run_log("rosters", list(extracted = 3, failed = 1), note = "test", p = lg); run_log("tables", list(people = 5), p = lg)
l <- read_lines(lg$run_log); stopifnot(length(l) == 6, str_detect(l[5], "extracted=3; failed=1"), str_detect(l[6], "\\| tables \\|"), str_detect(l[5], "\\| 9\\.00 \\|"))

# --- prompt freeze
pf <- file.path(tmp, "prompts", "extraction"); dir.create(pf, recursive = TRUE); f <- file.path(pf, "x_v1.md"); rec <- file.path(tmp, "freeze.md")
writeLines(c("---", "prompt: extract", "version: v1", "status: DRAFT (unused)", "---", "", "# System prompt", "", "Do the thing."), f)
expect_error(assert_prompt_frozen(f, record = rec), "not marked FROZEN")
h <- freeze_prompt(f, "claude-sonnet-5-5", "0.1.24", record = rec)
stopifnot(str_detect(read_file(f), "status: FROZEN"), assert_prompt_frozen(f, "claude-sonnet-5-5", record = rec), file.exists(rec), str_detect(read_file(rec), h))
expect_error(freeze_prompt(f, "claude-sonnet-5-5", "0.1.24", record = rec), "already frozen")
expect_error(assert_prompt_frozen(f, "claude-opus-5-5", record = rec), "pinned model")                 # model change is caught
write_file(paste0(read_file(f), "\nOne more line.\n"), f)
expect_error(assert_prompt_frozen(f, "claude-sonnet-5-5", record = rec), "edited after it was frozen")  # any edit is caught
expect_error(assert_prompt_frozen(file.path(pf, "other.md"), record = rec), ".")                           # missing/unrecorded file

# --- table integrity
mk <- \(reg, ppl, snap) { d <- file.path(tmp, paste0("t", sample.int(1e6, 1))); dir.create(d)
  write_csv(tibble(person_id = reg, minted_year = 2026L, status = "active", merged_into = NA, note = NA), file.path(d, "person_id_registry.csv"))
  write_csv(tibble(person_id = ppl), file.path(d, "people.csv")); write_csv(snap, file.path(d, "snapshots.csv")); d }
ok <- c("p000001", "p000002")
stopifnot(check_tables_integrity(mk(ok, ok, tibble(person_id = ok, year = 2026L, inst_id = "a"))))
expect_error(check_tables_integrity(mk(c("p000001", "p000003"), ok[1], tibble(person_id = "p000001", year = 2026L, inst_id = "a"))), "not sequential")
expect_error(check_tables_integrity(mk(ok, c(ok, "p000009"), tibble(person_id = ok, year = 2026L, inst_id = "a"))), "missing from the registry")
expect_error(check_tables_integrity(mk(ok, ok, tibble(person_id = c(ok, "p000009"), year = 2026L, inst_id = "a"))), "missing from people")
expect_error(check_tables_integrity(mk(ok, ok, tibble(person_id = c("p000001", "p000001"), year = 2026L, inst_id = "a"))), "not unique")

# --- hand-collected loader (fake extractor)
hd <- file.path(tmp, "hand"); dir.create(hd)
writeLines(c("# url: https://example.edu/soc/faculty  date: 2026-10-30", "Jane Roe, Professor", "John Doe, Associate Professor"), file.path(hd, "harvard__faculty.txt"))
writeLines(c("# url: https://example.edu/soc/emeriti  date: 2026-10-30", "Old Prof, Professor Emeritus"), file.path(hd, "harvard__emeriti.txt"))
fake <- function(inst_name, url, text, retrieved, system_prompt) tibble(name_raw = str_extract_all(text, "[A-Z][a-z]+ [A-Z][a-z]+(?=,)")[[1]], rank = "full", profile_url = NA_character_, source_url = url, retrieved = as.character(retrieved))
pr <- list(roster_dir = file.path(tmp, "rost"), sibling_dir = file.path(tmp, "sib")); cfg <- tibble(inst_id = "harvard", inst_name = "Harvard University")
r1 <- extract_hand_file(file.path(hd, "harvard__faculty.txt"), cfg, "sp", pr, fake); r2 <- extract_hand_file(file.path(hd, "harvard__emeriti.txt"), cfg, "sp", pr, fake)
stopifnot(r1$records == 2, file.exists(file.path(pr$roster_dir, "harvard.csv")), r2$records == 1, r2$status == "extracted",
          length(list.files(pr$sibling_dir, "^harvard__emeriti__")) == 1)
sib <- read_csv(list.files(pr$sibling_dir, full.names = TRUE)[1], show_col_types = FALSE); stopifnot(sib$list_type == "emeriti", sib$inst_id == "harvard", sib$retrieved == "2026-10-30")
stopifnot(str_detect(extract_hand_file(file.path(hd, "harvard__faculty.txt"), cfg, "sp", pr, fake)$status, "skipped"))   # resumable
writeLines("no header", file.path(hd, "harvard__joint.txt")); expect_error(extract_hand_file(file.path(hd, "harvard__joint.txt"), cfg, "sp", pr, fake), "first line")
writeLines(c("# url: u  date: 2026-10-30", "x"), file.path(hd, "harvard__bogus.txt")); expect_error(parse_hand_file(file.path(hd, "harvard__bogus.txt")), "unknown list type")
expect_error(parse_hand_file(file.path(hd, "badname.txt")), "<inst_id>__<list_type>")
writeLines(c("# url: https://e.edu/x  date: 2026-10-30", "A B, Professor"), file.path(hd, "nowhere__faculty.txt")); expect_error(extract_hand_file(file.path(hd, "nowhere__faculty.txt"), cfg, "sp", pr, fake), "unknown inst_id")
cat("all run-infrastructure tests passed\n")
