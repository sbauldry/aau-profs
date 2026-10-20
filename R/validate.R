# Validation scoring (codebook.md §7): agreement between the hand-coded sample and the pipeline.
library(tidyverse)

# Krippendorff's alpha for nominal data. `m` is a units x coders matrix (NA = no rating). Coincidence-matrix form.
kalpha_nominal <- function(m) {
  vals <- sort(unique(na.omit(as.vector(m))))
  if (length(vals) < 2) return(NA_real_)
  o <- matrix(0, length(vals), length(vals), dimnames = list(vals, vals))
  for (u in seq_len(nrow(m))) {
    v <- na.omit(m[u, ]); k <- length(v)
    if (k < 2) next
    for (i in seq_len(k)) for (j in seq_len(k)) if (i != j) o[as.character(v[i]), as.character(v[j])] <- o[as.character(v[i]), as.character(v[j])] + 1 / (k - 1)
  }
  nc <- rowSums(o); n <- sum(nc)
  d_o <- sum(o) - sum(diag(o)); d_e <- (sum(outer(nc, nc)) - sum(nc^2)) / (n - 1)
  1 - d_o / d_e
}

clean_chr <- \(x) { x <- str_to_lower(str_squish(x)); na_if(x, "") }
as_flag <- \(x) { x <- str_to_lower(str_squish(x)); case_when(x %in% c("true", "t", "yes", "y", "1") ~ TRUE, x %in% c("false", "f", "no", "n", "0") ~ FALSE, TRUE ~ NA) }
split_codes <- \(x) if (is.na(x) || x == "") character() else str_split_1(x, ";")

# key: pipeline answers (sample_key); sheet: the finished hand-coding sheet. Returns a list of tibbles.
score_validation <- function(key, sheet) {
  d <- key |> left_join(sheet |> select(sample_id, hand_rank, hand_included, starts_with("hand_area"), hand_notes), by = "sample_id") |>
    mutate(hand_rank = clean_chr(hand_rank), hand_included = as_flag(hand_included),
           pipeline_included = as_flag(as.character(pipeline_included)),
           across(starts_with("hand_area"), clean_chr))
  done <- d |> filter(!is.na(hand_rank))
  # rank
  rank_res <- done |> summarise(n = n(), agree = sum(pipeline_rank == hand_rank), pct = round(100 * agree / n, 1))
  rank_dis <- done |> filter(pipeline_rank != hand_rank) |> select(sample_id, name, pipeline_rank, hand_rank, hand_notes)
  # inclusion: percent agreement where the pipeline decided; undecided counted separately
  inc <- done |> filter(!is.na(hand_included))
  inc_dec <- inc |> filter(!is.na(pipeline_included))
  inc_res <- tibble(n_coded = nrow(inc), pipeline_decided = nrow(inc_dec), agree = sum(inc_dec$pipeline_included == inc_dec$hand_included),
                    pct_decided = round(100 * agree / pmax(pipeline_decided, 1), 1), pipeline_undecided = nrow(inc) - nrow(inc_dec),
                    undecided_hand_true = sum(is.na(inc$pipeline_included) & inc$hand_included %in% TRUE))
  inc_tab <- inc |> count(pipeline = pipeline_included, hand = hand_included)
  inc_dis <- inc_dec |> filter(pipeline_included != hand_included) |> select(sample_id, name, pipeline_included, hand_included, hand_notes)
  # areas: people in scope by both coders; the model's codes are in pipeline_codes (";"-separated, in order)
  ar <- done |> filter(hand_included %in% TRUE, pipeline_included %in% TRUE) |>
    mutate(model = map(pipeline_codes, split_codes),
           hand = pmap(list(hand_area_1, hand_area_2, hand_area_3), \(...) { x <- c(...); x[!is.na(x)] }))
  sections <- sort(unique(c(unlist(ar$model), unlist(ar$hand))))
  per_section <- map(sections, \(s) {
    h <- map_int(ar$hand, \(v) as.integer(s %in% v)); m <- map_int(ar$model, \(v) as.integer(s %in% v))
    tibble(section = s, n_hand = sum(h), n_model = sum(m), n_both = sum(h & m), alpha = round(kalpha_nominal(cbind(h, m)), 3))
  }) |> list_rbind() |> arrange(desc(n_hand + n_model))
  both_have <- ar |> filter(lengths(model) > 0, lengths(hand) > 0)
  first_pct <- if (nrow(both_have)) round(100 * mean(map2_lgl(both_have$hand, both_have$model, \(h, m) h[[1]] == m[[1]])), 1) else NA_real_
  share_pct <- if (nrow(both_have)) round(100 * mean(map2_lgl(both_have$hand, both_have$model, \(h, m) length(intersect(h, m)) > 0)), 1) else NA_real_
  areas_res <- tibble(n_people_in_scope_both = nrow(ar), n_both_coded = nrow(both_have), pct_first_code_agree = first_pct, pct_share_at_least_one = share_pct,
                      n_hand_uncoded = sum(lengths(ar$hand) == 0), n_model_uncoded = sum(lengths(ar$model) == 0),
                      mean_alpha = round(mean(per_section$alpha[per_section$n_hand + per_section$n_model > 0], na.rm = TRUE), 3),
                      n_sections = sum(per_section$n_hand + per_section$n_model > 0))
  list(n_rows = nrow(d), n_coded = nrow(done), rank = rank_res, rank_disagreements = rank_dis, inclusion = inc_res, inclusion_table = inc_tab,
       inclusion_disagreements = inc_dis, areas = areas_res, per_section = per_section)
}
