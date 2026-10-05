# ellmer type specification for extraction prompt v1 (prompts/extraction/extract_v1.md).
# All fields are required (the API limits optional/nullable fields); "not stated" is an empty
# string, converted to NA in R (see as_extract_tibble). Field names follow codebook.md §3.2-3.3. Fields prefixed with listing_/ *_evidence are
# extraction-only audit fields (raw HTML is not archived, so the supporting text is kept).
library(ellmer)

extract_schema_v1 <- type_object(
  "Faculty records found on one department page.",
  faculty = type_array(
    type_object(
      "One person listed as faculty on the page.",
      name_raw = type_string("Name exactly as listed."),
      name_first = type_string("First name; empty string if unsure."),
      name_middle = type_string("Middle name or initial, if listed."),
      name_last = type_string("Last name; null if unsure."),
      name_suffix = type_string("Jr., III, etc."),
      title_raw = type_string("Full title exactly as listed."),
      rank = type_enum(c("full", "associate", "assistant", "emeritus", "nontenure", "other", "unknown"),
                       "Rank per codebook 4.1."),
      named_chair = type_boolean("Holds a named or endowed professorship."),
      distinguished = type_boolean("Holds a university-level distinguished title."),
      appointment_type = type_enum(c("primary", "joint", "courtesy", "unknown"),
                                   "Appointment type per codebook 4.2."),
      joint_units = type_string("Other units, semicolon-separated."),
      admin_role = type_string("Current administrative role."),
      areas_raw = type_string("Research areas exactly as listed."),
      orcid = type_string("Bare ORCID iD if stated."),
      phd_inst = type_string("PhD institution if stated."),
      phd_year = type_string("Four-digit PhD year if stated."),
      profile_url = type_string("Absolute URL of the individual profile."),
      listing_section = type_string("Heading the person is listed under."),
      rank_evidence = type_string("Exact page text supporting rank."),
      appointment_evidence = type_string("Exact page text supporting appointment type."),
      review_flag = type_boolean("Needs hand review."),
      review_note = type_string("Reason for the flag.")
    )
  )
)

# Convert a model result to a tibble with NA for "not stated" and an integer phd_year.
as_extract_tibble <- function(res) {
  dplyr::as_tibble(res$faculty) |>
    dplyr::mutate(dplyr::across(where(is.character), \(x) dplyr::na_if(stringr::str_squish(x), "")),
                  phd_year = suppressWarnings(as.integer(phd_year)))
}
