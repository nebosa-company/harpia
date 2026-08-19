# Ticket-code extraction and email redaction for support messages.

.CODE <- "\\b[A-Z]{3}-[0-9]{4}\\b"
.EMAIL <- "[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\\.[A-Za-z]{2,})"

extract_codes <- function(x) {
  safe <- as.character(x)
  safe[is.na(safe)] <- ""
  unname(regmatches(safe, gregexpr(.CODE, safe, perl = TRUE)))
}

first_code <- function(x) {
  vapply(
    extract_codes(x),
    function(v) if (length(v) > 0L) v[[1L]] else NA_character_,
    character(1)
  )
}

mask_emails <- function(x) {
  gsub(.EMAIL, "***@\\1", x, perl = TRUE)
}

replace_codes <- function(x, map) {
  out <- as.character(x)
  idx <- which(!is.na(out))
  if (length(idx) == 0L) {
    return(out)
  }
  part <- out[idx]
  m <- gregexpr(.CODE, part, perl = TRUE)
  regmatches(part, m) <- lapply(regmatches(part, m), function(v) {
    hit <- v %in% names(map)
    v[hit] <- unname(map[v[hit]])
    v
  })
  out[idx] <- part
  out
}
