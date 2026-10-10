# Stage 2: scraping functions (codebook.md §10 conduct rules).
#
# - robots.txt checked once per host; disallowed pages are not fetched.
# - Identifying user-agent with contact from SCRAPER_CONTACT.
# - >= 2 s between requests to the same host; one attempt per page, no retries.
# - Bot challenges / blocks are detected, logged, and NOT worked around.
# - Every attempt (success or failure) is appended to a manifest.
#
# Page text keeps hyperlinks as "link text <absolute url>" (needed for profile_url).

library(tidyverse)
library(httr2)
library(rvest)
library(robotstxt)
library(chromote)

scrape_delay <- 2
.scrape <- new.env()
.scrape$last_request <- list()
.scrape$robots <- list()
.scrape$browser <- NULL

scrape_ua <- function() {
  contact <- Sys.getenv("SCRAPER_CONTACT")
  if (!nzchar(contact)) stop("SCRAPER_CONTACT is not set in ~/.Renviron")
  str_glue("aau-profs-research/1.0 (academic research; contact: {contact})")
}

url_host <- function(url) str_match(url, "^https?://([^/]+)")[, 2]
url_path <- function(url) str_replace(url, "^https?://[^/]+", "") |> (\(p) if_else(p == "", "/", p))()

polite_wait <- function(url) {
  host <- url_host(url)
  last <- .scrape$last_request[[host]]
  if (!is.null(last)) {
    wait <- scrape_delay - as.numeric(difftime(Sys.time(), last, units = "secs"))
    if (wait > 0) Sys.sleep(wait)
  }
  .scrape$last_request[[host]] <- Sys.time()
}

# TRUE / FALSE; NA when robots.txt could not be read (treated as allowed, but recorded)
robots_allows <- function(url) {
  host <- url_host(url)
  if (is.null(.scrape$robots[[host]])) {
    .scrape$robots[[host]] <- tryCatch(
      robotstxt(domain = host, user_agent = scrape_ua(), warn = FALSE, force = TRUE),
      error = \(e) NA)
  }
  rt <- .scrape$robots[[host]]
  if (!inherits(rt, "robotstxt")) return(NA)
  isTRUE(rt$check(paths = url_path(url), bot = "aau-profs-research"))
}

# A challenge marker only counts when the page is small: real pages from WAF-protected sites
# (e.g. msu) also embed the vendor's script, so the marker alone is not evidence of a block.
looks_blocked <- function(html, status, final_url = "") {
  marker <- str_detect(html, regex("_Incapsula_Resource|Just a moment|cf-browser-verification|captcha|Access Denied|Request unsuccessful", TRUE))
  status %in% c(401, 403, 429) ||
    nchar(html) < 100 ||                                  # empty body (e.g. 202 challenge with no content)
    str_detect(coalesce(final_url, ""), "[?&]challenge=") ||
    (marker && nchar(html) < 5000) ||
    (nchar(html) < 600 && str_detect(html, regex("<body>\\s*</body>", TRUE)))
}

browser_session <- function() {
  if (is.null(.scrape$browser)) {
    .scrape$browser <- ChromoteSession$new()
    .scrape$browser$Network$setUserAgentOverride(userAgent = scrape_ua())
  }
  .scrape$browser
}
close_browser <- function() {
  if (!is.null(.scrape$browser)) try(.scrape$browser$close(), silent = TRUE)
  .scrape$browser <- NULL
}

# Wait until client-side rendering settles: text length unchanged for 2 polls and no
# "Loading, please wait" placeholder (max `max_s` seconds).
wait_for_render <- function(b, max_s = 20) {
  prev <- -1; stable <- 0
  for (k in seq_len(max_s)) {
    Sys.sleep(1)
    len <- b$Runtime$evaluate("document.body ? document.body.innerText.length : 0")$result$value
    loading <- b$Runtime$evaluate("document.body ? /loading, please wait|loading\\.\\.\\./i.test(document.body.innerText) : true")$result$value
    stable <- if (!isTRUE(loading) && identical(len, prev)) stable + 1 else 0
    prev <- len
    if (stable >= 2) break
  }
}

fetch_html <- function(url, method = c("http", "chromote")) {
  method <- match.arg(method)
  if (method == "http") {
    resp <- request(url) |> req_user_agent(scrape_ua()) |> req_timeout(30) |>
      req_error(is_error = \(r) FALSE) |> req_perform()
    html <- tryCatch(resp_body_string(resp), error = \(e) "")
    list(status = resp_status(resp), final_url = resp_url(resp), html = html)
  } else {
    b <- browser_session()
    b$Page$navigate(url, wait_ = FALSE)
    b$Page$loadEventFired(timeout_ = 30)
    wait_for_render(b)
    html <- b$Runtime$evaluate("document.documentElement.outerHTML")$result$value
    final <- b$Runtime$evaluate("window.location.href")$result$value
    list(status = 200L, final_url = final, html = html)  # chromote does not expose the HTTP status simply
  }
}

# Page text with hyperlinks kept as "link text <absolute url>"
page_to_text <- function(html, base_url) {
  doc <- read_html(html)
  xml2::xml_remove(html_elements(doc, "script, style, noscript, template"))  # code, never content
  node <- html_element(doc, "main")
  if (inherits(node, "xml_missing") || nchar(html_text2(node)) < 200) {
    node <- html_element(doc, "body")
    xml2::xml_remove(html_elements(node, "nav, header, footer, aside"))     # site chrome, when no <main>
  }
  for (a in html_elements(node, "a")) {
    href <- html_attr(a, "href")
    if (!is.na(href) && !str_detect(href, "^(#|mailto:|tel:|javascript:)"))
      xml2::xml_text(a) <- str_glue("{str_squish(html_text2(a))} <{url_absolute(href, base_url)}>")
  }
  html_text2(node) |> str_replace_all("\n{3,}", "\n\n")
}

# URL of a "next page" link, or NA
next_page_url <- function(html, base_url) {
  doc <- read_html(html)
  a <- html_elements(doc, "a[rel='next'], li.pager__item--next a, a:contains('Next')")
  href <- html_attr(a, "href")
  href <- href[!is.na(href)]
  if (length(href)) url_absolute(href[[1]], base_url) else NA_character_
}

# Further roster pages linked from a page: numbered pagers (?page=N on the same path) and
# A-Z letter pagers (same directory, final path segment a single capital letter).
pager_urls <- function(html, base_url, kind = c("pages", "letters")) {
  kind <- match.arg(kind)
  hrefs <- read_html(html) |> html_elements("a") |> html_attr("href") |> discard(is.na)
  urls <- url_absolute(hrefs, base_url) |> str_remove("#.*$") |> unique()
  base_path <- str_remove(base_url, "[?#].*$") |> str_remove("/$")
  if (kind == "pages") {
    keep <- urls[str_detect(urls, "[?&]page=[1-9][0-9]*(&|$)") & str_remove(urls, "[?#].*$") |> str_remove("/$") == base_path]
  } else {
    keep <- urls[str_detect(urls, "/[A-Z]$") & str_remove(urls, "/[A-Z]$") == base_path]
  }
  sort(keep)
}

manifest_row <- function(inst_id, kind, url, method, status, final_url = NA, file = NA, chars = NA,
                         robots = NA, note = NA) {
  tibble(inst_id, kind, url, method, retrieved = as.character(Sys.Date()), status = as.character(status),
         final_url = final_url, html_file = file, text_chars = chars, robots_ok = robots, note = note)
}

# Fetch one page with all conduct checks. Returns list(text, manifest).
scrape_page <- function(inst_id, url, method, kind, html_dir, tag = "page") {
  robots <- robots_allows(url)
  if (isFALSE(robots))
    return(list(text = NA_character_, html = NA_character_,
                manifest = manifest_row(inst_id, kind, url, method, "skipped", robots = FALSE, note = "disallowed by robots.txt")))
  polite_wait(url)
  res <- tryCatch(fetch_html(url, method), error = \(e) list(error = conditionMessage(e)))
  if (!is.null(res$error))
    return(list(text = NA_character_, html = NA_character_,
                manifest = manifest_row(inst_id, kind, url, method, "error", robots = robots,
                                        note = str_sub(str_replace_all(res$error, "\n", " "), 1, 160))))
  if (looks_blocked(res$html, res$status, res$final_url))
    return(list(text = NA_character_, html = NA_character_,
                manifest = manifest_row(inst_id, kind, url, method, "blocked", res$final_url, robots = robots,
                                        note = "bot block or challenge: not worked around; collect by hand")))
  dir.create(html_dir, recursive = TRUE, showWarnings = FALSE)
  file <- file.path(html_dir, str_glue("{tag}.html"))
  write_file(res$html, file)
  text <- page_to_text(res$html, res$final_url)
  list(text = text, html = res$html,
       manifest = manifest_row(inst_id, kind, url, method, res$status, res$final_url, file, nchar(text), robots,
                               if (res$status >= 400) "http error status" else NA))
}

# Split long text into chunks at line boundaries; the last `overlap` lines of a chunk repeat at
# the start of the next so a person cut at a boundary appears whole in one chunk.
# Duplicates across chunks are resolved after extraction (same name + URL).
chunk_text <- function(text, max_chars = 20000, overlap = 6) {
  if (is.na(text) || nchar(text) <= max_chars) return(text)
  lines <- str_split_1(text, "\n")
  chunks <- list(); cur <- character(); n <- 0
  for (ln in lines) {
    if (n + nchar(ln) + 1 > max_chars && length(cur)) {
      chunks[[length(chunks) + 1]] <- paste(cur, collapse = "\n")
      cur <- tail(cur, overlap); n <- sum(nchar(cur) + 1)
    }
    cur <- c(cur, ln); n <- n + nchar(ln) + 1
  }
  chunks[[length(chunks) + 1]] <- paste(cur, collapse = "\n")
  unlist(chunks)
}

# For multi-page rosters: remove long lines (>= 40 characters) that repeat on nearly every page
# (site menus, department lists). Short lines such as titles are always kept.
drop_boilerplate <- function(texts, min_pages = 3, share = 0.9, min_chars = 40) {
  if (length(texts) < min_pages) return(texts)
  lines <- map(texts, \(t) unique(str_split_1(t, "\n")))
  counts <- table(unlist(lines))
  boiler <- names(counts)[counts >= share * length(texts) & nchar(names(counts)) >= min_chars]
  map_chr(texts, \(t) str_split_1(t, "\n") |> setdiff(boiler) |> paste(collapse = "\n"))
}

# Roster: follows pagination when the config asks for it (paginate = "next" follows a Next link,
# "pages" follows ?page=N links, "letters" follows A-Z letter pages). Returns list(chunks, manifest).
scrape_roster <- function(cfg, year, root = "data/raw_html") {
  id <- cfg$inst_id
  if (cfg$method %in% c("hand", "none"))
    return(list(chunks = character(),
                manifest = manifest_row(id, "roster", cfg$roster_url, cfg$method, "skipped",
                                        note = if (cfg$method == "none") "no sociology department" else cfg$note)))
  mode <- cfg$paginate
  if (isTRUE(mode)) mode <- "next"
  html_dir <- file.path(root, year, id)
  queue <- cfg$roster_url; seen <- character(); texts <- character(); manifest <- list(); i <- 0
  while (length(queue) && i < cfg$max_pages) {
    url <- queue[[1]]; queue <- queue[-1]
    if (url %in% seen) next
    i <- i + 1; seen <- c(seen, url)
    page <- scrape_page(id, url, cfg$method, "roster", html_dir, tag = str_glue("roster_p{i}"))
    manifest[[length(manifest) + 1]] <- page$manifest
    if (is.na(page$text)) { if (i == 1) break else next }
    texts <- c(texts, page$text)
    more <- switch(as.character(mode),
                   "next" = next_page_url(page$html, page$manifest$final_url),
                   "pages" = pager_urls(page$html, cfg$roster_url, "pages"),
                   "letters" = pager_urls(page$html, cfg$roster_url, "letters"),
                   NA_character_)
    queue <- c(queue, setdiff(na.omit(more), c(seen, queue)))
  }
  list(chunks = unlist(map(paste(drop_boilerplate(texts), collapse = "\n\n"), chunk_text)), manifest = list_rbind(manifest))
}

# One individual profile page.
scrape_profile <- function(inst_id, url, method, year, root = "data/raw_html") {
  slug <- str_replace_all(str_remove(url, "^https?://"), "[^A-Za-z0-9]+", "_") |> str_sub(1, 80)
  scrape_page(inst_id, url, method, "profile", file.path(root, year, inst_id, "profiles"), tag = slug)
}
