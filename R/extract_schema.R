# ellmer type specification for extraction prompt v1 (prompts/extraction/extract_v1.md).
# Field names follow codebook.md §3.2-3.3. Fields prefixed with listing_/ *_evidence are
# extraction-only audit fields (raw HTML is not archived, so the supporting text is kept).
library(ellmer)

extract_schema_v1 <- type_object(
  "Faculty records found on one department page.",
  faculty = type_array(
    type_object(
      "One person listed as faculty on the page.",
      name_raw = type_string("Name exactly as listed."),
      name_first = type_string("First name; null if unsure.", required = FALSE),
      name_middle = type_string("Middle name or initial, if listed.", required = FALSE),
      name_last = type_string("Last name; null if unsure.", required = FALSE),
      name_suffix = type_string("Jr., III, etc.", required = FALSE),
      title_raw = type_string("Full title exactly as listed.", required = FALSE),
      rank = type_enum(c("full", "associate", "assistant", "emeritus", "nontenure", "other", "unknown"),
                       "Rank per codebook 4.1."),
      named_chair = type_boolean("Holds a named or endowed professorship."),
      distinguished = type_boolean("Holds a university-level distinguished title."),
      appointment_type = type_enum(c("primary", "joint", "courtesy", "unknown"),
                                   "Appointment type per codebook 4.2."),
      joint_units = type_string("Other units, semicolon-separated.", required = FALSE),
      admin_role = type_string("Current administrative role.", required = FALSE),
      areas_raw = type_string("Research areas exactly as listed.", required = FALSE),
      orcid = type_string("Bare ORCID iD if stated.", required = FALSE),
      phd_inst = type_string("PhD institution if stated.", required = FALSE),
      phd_year = type_integer("PhD year if stated.", required = FALSE),
      profile_url = type_string("Absolute URL of the individual profile.", required = FALSE),
      listing_section = type_string("Heading the person is listed under.", required = FALSE),
      rank_evidence = type_string("Exact page text supporting rank.", required = FALSE),
      appointment_evidence = type_string("Exact page text supporting appointment type.", required = FALSE),
      review_flag = type_boolean("Needs hand review."),
      review_note = type_string("Reason for the flag.", required = FALSE)
    )
  )
)
