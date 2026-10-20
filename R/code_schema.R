# ellmer type specification for coding prompt v1 (prompts/coding/code_v1.md).
# The vocabulary is read from codebook.md §5, the single source, so the schema cannot drift from it.
# All fields are required; "none" is an empty string or an empty list.
library(ellmer)

asa_codes <- function(codebook = "codebook.md") {
  txt <- readr::read_file(codebook)
  sec <- stringr::str_extract(txt, "(?s)## 5\\. Research area vocabulary.*?### 5\\.1")
  stringr::str_match_all(sec, "(?m)^\\| `(\\w+)` \\|")[[1]][, 2]
}

code_schema_v1 <- function(codes = asa_codes()) {
  type_object(
    "Area codes for each input record.",
    results = type_array(
      type_object(
        "Coding result for one person.",
        person_id = type_string("Copied unchanged from the input."),
        codes = type_array(
          type_object(
            "One assigned section.",
            area_code = type_enum(codes, "Vocabulary code."),
            matched_text = type_string("Shortest exact fragment of areas_raw supporting the code.")
          ),
          "Up to three codes, ordered by prominence; empty if none."),
        more_available = type_boolean("More than three distinct sections could be assigned."),
        review_flag = type_boolean("Needs hand review."),
        review_note = type_string("Reason for the flag; empty string if none.")
      )
    )
  )
}
