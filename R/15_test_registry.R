# Test the person_id registry and matching rules (codebook §3.2a, §6) on synthetic perturbations of the
# trial data. Writes only to a temporary directory; never touches data/final or the trial registry.
# Usage: Rscript R/15_test_registry.R
source("R/build_tables.R")

tmp <- file.path(tempdir(), "reg_test"); in25 <- file.path(tmp, "in25"); in26 <- file.path(tmp, "in26"); out <- file.path(tmp, "out")
dir.create(in25, recursive = TRUE); dir.create(in26, recursive = TRUE)
src <- list.files("data/interim/profiles_trial", "_merged\\.csv$", full.names = TRUE) |> keep(\(f) str_detect(f, "duke|umn|cuboulder|ku_|uva"))
for (f in src) file.copy(f, in25)

# Year 1 (2025 in the test): baseline
t25 <- build_tables(in25, 2025, out)
reg1 <- registry_read(file.path(out, "person_id_registry.csv"))
stopifnot(nrow(reg1) == nrow(t25$people), !anyDuplicated(reg1$person_id), identical(reg1$person_id[1], "p000001"))

# Year 2: same files, then perturb
rd <- \(f) read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"))
dat <- map(list.files(in25, full.names = TRUE), rd) |> set_names(basename(list.files(in25)))
pick <- t25$assigned |> filter(rank == "full", !is.na(areas_raw), !is.na(phd_inst), !is.na(phd_year), is.na(orcid)) |> slice_head(n = 3)
a <- pick[1, ]; b <- pick[2, ]; c3 <- pick[3, ]
f_of <- \(id) paste0(id, "_merged.csv")
# (a) fuzzy: first name changes by one letter -> candidate only, new ID, no link
dat[[f_of(a$inst_id)]] <- dat[[f_of(a$inst_id)]] |> mutate(name_first = if_else(name_raw == a$name_raw, paste0(name_first, "x"), name_first))
# (b) move: same name, same PhD, different institution -> candidate only, new ID, no `moved`
other_inst <- setdiff(str_remove(names(dat), "_merged.csv"), b$inst_id)[1]
mv <- dat[[f_of(b$inst_id)]] |> filter(name_raw == b$name_raw)
dat[[f_of(b$inst_id)]] <- dat[[f_of(b$inst_id)]] |> filter(name_raw != b$name_raw)
dat[[f_of(other_inst)]] <- bind_rows(dat[[f_of(other_inst)]], mv |> mutate(inst_id = other_inst))
# (c) ORCID: give c3 an ORCID in year 1 (patch the year-1 tables), then rename in year 2 -> matches on ORCID
sn <- read_csv(file.path(out, "people.csv"), show_col_types = FALSE, col_types = cols(.default = "c"))
sn$orcid[sn$person_id == c3$person_id] <- "0000-0001-2345-6789"; write_csv(sn, file.path(out, "people.csv"))
dat[[f_of(c3$inst_id)]] <- dat[[f_of(c3$inst_id)]] |>
  mutate(name_first = if_else(name_raw == c3$name_raw, "Zzyzx", name_first), name_raw = if_else(name_raw == c3$name_raw, "Zzyzx Renamed", name_raw),
         orcid = if_else(name_raw == "Zzyzx Renamed", "0000-0001-2345-6789", orcid))
iwalk(dat, \(d, nm) write_csv(d, file.path(in26, nm)))

t26 <- build_tables(in26, 2026, out)
asg <- t26$assigned
idx <- \(x) which(asg$inst_id == x$inst_id & asg$name_raw == x$name_raw)
# unchanged people keep their ID and match on name
same <- inner_join(select(t25$assigned, inst_id, name_key, id25 = person_id), select(asg, inst_id, name_key, id26 = person_id, match_rule), by = c("inst_id", "name_key"))
stopifnot(all(same$id25 == same$id26), all(same$match_rule %in% c("name", "orcid")))
cat("unchanged people keep IDs:", nrow(same), "\n")
# (a) fuzzy: new ID, candidate note naming the old ID, flagged, no link
ra <- asg[asg$inst_id == a$inst_id & asg$name_raw == a$name_raw, ]
stopifnot(nrow(ra) == 1, ra$match_rule == "new", ra$person_id != a$person_id, str_detect(ra$cand_note, a$person_id))
# (b) move: new ID, candidate note, flagged, still no link
rb <- asg[asg$inst_id == other_inst & asg$name_raw == b$name_raw, ]
stopifnot(nrow(rb) == 1, rb$match_rule == "new", rb$person_id != b$person_id, str_detect(rb$cand_note, b$person_id))
# (c) ORCID: renamed person keeps the ID
rc <- asg[asg$name_raw == "Zzyzx Renamed", ]
stopifnot(nrow(rc) == 1, rc$match_rule == "orcid", rc$person_id == c3$person_id)
# registry: grew only by the 2 new IDs, no reuse, sequential
reg2 <- registry_read(file.path(out, "person_id_registry.csv"))
stopifnot(nrow(reg2) == nrow(reg1) + 2, !anyDuplicated(reg2$person_id), all(reg1$person_id %in% reg2$person_id),
          identical(reg2$person_id, sprintf("p%06d", seq_len(nrow(reg2)))))
# rerun of the same year is idempotent
t26b <- build_tables(in26, 2026, out)
stopifnot(nrow(registry_read(file.path(out, "person_id_registry.csv"))) == nrow(reg2), all(t26b$assigned$match_rule != "new"))
# first_year: people seen in year 1 keep first_year 2025
stopifnot(all(t26b$people$first_year[t26b$people$person_id %in% t25$people$person_id] == 2025))
cat("all registry and matching tests passed\n")
