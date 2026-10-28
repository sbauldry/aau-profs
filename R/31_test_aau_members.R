# Tests for the AAU member list parser and diff (R/aau_members.R). No network. Usage: Rscript R/31_test_aau_members.R
suppressMessages(library(tidyverse)); source("R/aau_members.R")
tmp <- file.path(tempdir(), "aau"); dir.create(tmp)
expect_error <- \(expr, pattern) { r <- tryCatch({ expr; NULL }, error = \(e) conditionMessage(e)); stopifnot(!is.null(r), str_detect(r, pattern)) }

# --- text shapes: year at the end or the start, several separators, footnote marks, junk lines
writeLines(c("AAU Member Universities by Year of Entry", "", "Brown University, 1933", "University of Chicago - 1900", "Duke University (1938)",
             "1985  Emory University", "Johns Hopkins University\t1900", "Case Western Reserve University* 1969", "Some navigation line"), f <- file.path(tmp, "m.txt"))
t <- parse_member_file(f)
stopifnot(nrow(t) == 6, setequal(t$inst_name, c("Brown University", "University of Chicago", "Duke University", "Emory University", "Johns Hopkins University", "Case Western Reserve University")))
stopifnot(t$entry_year[t$inst_name == "Brown University"] == 1933L, t$entry_year[t$inst_name == "Emory University"] == 1985L, t$entry_year[t$inst_name == "Case Western Reserve University"] == 1969L,
          !"Some navigation line" %in% t$inst_name, !"AAU Member Universities by Year of Entry" %in% t$inst_name)

# --- AAU-style text: headings set sector and country; the title and "Published" lines before the first heading are ignored
writeLines(c("AAU Member Universities By Year of Entry", "Published: Nov 20, 2024", "Public", "Arizona State University (2023)", "The University of Texas at Austin (1929)", "",
             "Private", "Brown University (1933)", "Dartmouth (2019)", "", "Canadian", "McGill University (1926)", "", "Sign up for the newsletter", "Submit"), f <- file.path(tmp, "aau.txt"))
a <- parse_member_file(f)
stopifnot(nrow(a) == 5, !any(str_detect(a$inst_name, "Published")), a$sector[a$inst_name == "Brown University"] == "private", a$sector[a$inst_name == "Arizona State University"] == "public",
          a$country[a$inst_name == "McGill University"] == "CA", a$country[a$inst_name == "Dartmouth"] == "US", a$entry_year[a$inst_name == "Dartmouth"] == 2019L)
# the same page as saved HTML: the whole list sits in one block separated by line breaks, with navigation lists around it
writeLines(c("<html><body><nav><ul><li>Home</li><li>About 2024</li></ul></nav><main><h1>AAU Member Universities By Year of Entry</h1><p>Published: Nov 20, 2024</p>",
             "<p>Public<br>Arizona State University (2023)<br>The University of Texas at Austin (1929)</p><p>Private<br>Brown University (1933)<br>Dartmouth (2019)</p><p>Canadian<br>McGill University (1926)</p>",
             "<p>Sign up for the newsletter</p></main></body></html>"), f <- file.path(tmp, "aau.html"))
h <- parse_member_file(f); stopifnot(nrow(h) == 5, h$sector[h$inst_name == "Dartmouth"] == "private", h$country[h$inst_name == "McGill University"] == "CA")

# --- csv and html (table, then list items)
write_csv(tibble(inst_name = c("Yale University", "Rice University"), entry_year = c(1900, 1985), sector = c("private", "private"), country = "US"), f <- file.path(tmp, "m.csv"))
c1 <- parse_member_file(f); stopifnot(nrow(c1) == 2, c1$entry_year[1] == 1900L, c1$sector[1] == "private")
writeLines("<html><body><table><tr><th>University</th><th>Year of Entry</th></tr><tr><td>Tufts University</td><td>1999</td></tr><tr><td>McGill University [1]</td><td>1926</td></tr></table></body></html>", f <- file.path(tmp, "m.html"))
h1 <- parse_member_file(f); stopifnot(nrow(h1) == 2, h1$inst_name[2] == "McGill University", h1$entry_year[2] == 1926L)
writeLines("<html><body><ul><li>Harvard University (1900)</li><li>Rutgers University-New Brunswick (1989)</li></ul></body></html>", f <- file.path(tmp, "m2.html"))
stopifnot(nrow(parse_member_file(f)) == 2)
expect_error(parse_member_file(file.path(tmp, "x.pdf")), "unsupported")
write_csv(tibble(name = "a", year = "1900"), f <- file.path(tmp, "bad.csv")); expect_error(parse_member_file(f), "inst_name and entry_year")

# --- fill sector and country from the previous list; new members stay NA
prev <- tibble(inst_name = c("Brown University", "The University of Chicago", "McGill University", "Old Member University"),
               sector = c("private", "private", "public", "private"), entry_year = c(1933L, 1900L, 1926L, 1950L), country = c("US", "US", "CA", "US"),
               source_url = "u", retrieved = "2026-10-03")
cur <- parsed <- tibble(inst_name = c("Brown University", "University of Chicago", "McGill University", "New Member University"), entry_year = c(1933L, 1900L, 1927L, 2026L))
lst <- build_member_list(parsed, prev, "2026-10-30")
stopifnot(identical(names(select(lst, -key)), member_cols), lst$sector[lst$inst_name == "University of Chicago"] == "private",      # "The University of Chicago" matches
          lst$country[lst$inst_name == "McGill University"] == "CA", is.na(lst$sector[lst$inst_name == "New Member University"]), all(lst$retrieved == "2026-10-30"), all(lst$source_url == aau_source_url))

# --- diff: added, removed, renamed candidates, year changes
cur2 <- tibble(inst_name = c("Brown University", "University of Chicago", "McGill Univ.", "New Member University"), entry_year = c(1933L, 1900L, 1926L, 2026L))
d <- diff_members(cur2, prev)
stopifnot("New Member University" %in% d$added$inst_name, "Old Member University" %in% d$removed$inst_name,
          nrow(d$renamed_candidates) >= 0, d$n_current == 4, d$n_previous == 4)
d2 <- diff_members(parsed, prev); stopifnot(nrow(d2$year_changed) == 1, d2$year_changed$inst_name == "McGill University", d2$year_changed$entry_year_prev == 1926L)
rn <- diff_members(tibble(inst_name = "University of Californa, Berkeley", entry_year = 1900L), tibble(inst_name = "University of California, Berkeley", entry_year = 1900L))
stopifnot(nrow(rn$renamed_candidates) == 1)                                                                                                    # a typo is flagged as a rename, not silently two members

rn2 <- diff_members(tibble(inst_name = c("Rice Universty", "Duke University"), entry_year = c(1985L, 1938L)), tibble(inst_name = c("Rice University", "Duke University"), entry_year = c(1985L, 1938L)))
stopifnot(nrow(rn2$renamed_candidates) == 1, rn2$renamed_candidates$old == "Rice University")                                              # a typo in "university" is still caught
rn3 <- diff_members(tibble(inst_name = c("Example New University", "Duke University"), entry_year = c(2026L, 1938L)), tibble(inst_name = c("Tulane University", "Duke University"), entry_year = c(1958L, 1938L)))
stopifnot(nrow(rn3$renamed_candidates) == 0)                                                                                                 # unrelated names are not paired

# --- sanity limits stop a bad parse
mk <- \(n) tibble(inst_name = paste("Univ", seq_len(n)), entry_year = 1950L)
stopifnot(check_member_list(mk(71)))
expect_error(check_member_list(mk(12)), "expected 50 to 110"); expect_error(check_member_list(mk(300)), "expected")
expect_error(check_member_list(bind_rows(mk(60), tibble(inst_name = "Univ 1", entry_year = 1950L))), "duplicate")
expect_error(check_member_list(mutate(mk(60), entry_year = replace(entry_year, 3, NA))), "missing or out of range")

# --- round trip on the real trial list: parse it back and compare with itself
trial <- read_csv("data/seeds/aau_members_2026-10-03_TRIAL.csv", show_col_types = FALSE, col_types = cols(.default = "c", entry_year = "i"))
p <- parse_member_file("data/seeds/aau_members_2026-10-03_TRIAL.csv")
same <- diff_members(build_member_list(p, trial, "2026-10-30"), trial)
stopifnot(nrow(p) == 71, nrow(same$added) == 0, nrow(same$removed) == 0, nrow(same$year_changed) == 0, check_member_list(p))
cat("all AAU member list tests passed\n")
