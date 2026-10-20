# Tests for the validation scoring (R/validate.R) on small constructed cases.
source("R/validate.R")
# Krippendorff's alpha: closed-form checks for two coders, binary
stopifnot(isTRUE(all.equal(kalpha_nominal(cbind(c(1, 1, 0, 0), c(1, 1, 0, 0))), 1)),            # perfect agreement
          isTRUE(all.equal(kalpha_nominal(cbind(c(1, 0), c(0, 1))), -0.5)),                       # complete disagreement on 2 units
          is.na(kalpha_nominal(cbind(c(1, 1, 1), c(1, 1, 1)))))                                   # no variation: undefined
x <- c(1, 1, 0, 0, 1, 0, 0, 1); y <- c(1, 0, 0, 0, 1, 0, 1, 1)                                   # 2 disagreements in 8 units
n <- 16; n1 <- sum(x) + sum(y); n0 <- n - n1; d <- sum(x != y)
stopifnot(isTRUE(all.equal(kalpha_nominal(cbind(x, y)), 1 - d * (n - 1) / (n0 * n1))))          # matches the closed form
stopifnot(isTRUE(all.equal(kalpha_nominal(cbind(c(1, 0, NA), c(1, 1, 0))), kalpha_nominal(cbind(c(1, 0), c(1, 1))))))   # units with one rating are ignored

key <- tribble(~sample_id, ~name, ~pipeline_rank, ~pipeline_included, ~pipeline_codes, ~stratum,
               "V01", "A", "full", "TRUE", "inequality;medical", "A",
               "V02", "B", "full", "TRUE", "rem", "A",
               "V03", "C", "full", "TRUE", "family;gender", "A",
               "V04", "D", "full", "TRUE", NA, "A",
               "V05", "E", "unknown", NA, NA, "B",
               "V06", "F", "emeritus", "FALSE", NA, "B",
               "V07", "G", "full", "TRUE", "crime", "A")
sheet <- tribble(~sample_id, ~hand_rank, ~hand_included, ~hand_area_1, ~hand_area_2, ~hand_area_3, ~hand_notes,
                 "V01", "full", "TRUE", "inequality", "medical", NA, NA,        # full agreement
                 "V02", "full", "TRUE", "rem", "gender", NA, NA,                 # shared first code; hand adds one
                 "V03", "associate", "FALSE", NA, NA, NA, "rank wrong",          # rank and inclusion disagree
                 "V04", "full", "TRUE", NA, NA, NA, NA,                          # both uncoded
                 "V05", "full", "TRUE", "culture", NA, NA, NA,                   # pipeline undecided
                 "V06", "emeritus", "FALSE", NA, NA, NA, NA,                     # agree
                 "V07", "full", "TRUE", "religion", NA, NA, NA)                  # no shared code
r <- score_validation(key, sheet)
stopifnot(r$n_coded == 7, r$rank$agree == 5, r$rank$pct == round(100 * 5 / 7, 1),               # V03 and V05 differ
          r$inclusion$pipeline_decided == 6, r$inclusion$agree == 5, r$inclusion$pct_decided == round(100 * 5 / 6, 1))   # V03 is the one miss
stopifnot(r$inclusion$pipeline_undecided == 1, r$inclusion$undecided_hand_true == 1)                                 # V05
stopifnot(nrow(r$rank_disagreements) == 2, "V03" %in% r$inclusion_disagreements$sample_id)
# areas: people in scope by both = V01, V02, V04, V07 (V03 hand says out of scope)
stopifnot(r$areas$n_people_in_scope_both == 4, r$areas$n_both_coded == 3, r$areas$n_hand_uncoded == 1,
          r$areas$pct_first_code_agree == round(100 * 2 / 3, 1), r$areas$pct_share_at_least_one == round(100 * 2 / 3, 1))
ps <- r$per_section |> filter(section == "inequality"); stopifnot(ps$n_hand == 1, ps$n_model == 1, ps$n_both == 1, ps$alpha == 1)
ps <- r$per_section |> filter(section == "gender"); stopifnot(ps$n_hand == 1, ps$n_model == 0, ps$n_both == 0)
cat("all validation scoring tests passed\n")
