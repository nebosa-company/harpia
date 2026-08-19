source("logparse.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)

# --- empty input -------------------------------------------------------
check(identical(extract_codes(character(0)), list()),
      "empty input gives an empty list")
check(identical(first_code(character(0)), character(0)),
      "empty input gives character(0)")
check(identical(mask_emails(character(0)), character(0)),
      "mask_emails on empty input")
check(identical(replace_codes(character(0), c(a = "b")), character(0)),
      "replace_codes on empty input")

# --- an all-NA vector --------------------------------------------------
nas <- c(NA_character_, NA_character_)
check(identical(extract_codes(nas), list(character(0), character(0))),
      "NA everywhere")
check(identical(first_code(nas), c(NA_character_, NA_character_)),
      "first_code on all NA")
check(all(is.na(mask_emails(nas))), "mask_emails on all NA")
check(all(is.na(replace_codes(nas, c("ABC-1234" = "X")))),
      "replace_codes on all NA")

# --- boundary cases for what counts as a code --------------------------
b <- c("ABC-1234ABC", "9ABC-1234", "ABC-1234-XYZ-0009", "(ABC-1234)",
       "AB-1234", "ABCD-123", "ABC_1234")
eb <- extract_codes(b)
check(identical(eb[[1]], character(0)), "letters straight after the digits")
check(identical(eb[[2]], character(0)), "a digit straight before the letters")
check(identical(eb[[3]], c("ABC-1234", "XYZ-0009")),
      "a hyphen delimits both codes")
check(identical(eb[[4]], "ABC-1234"), "parentheses delimit a code")
check(identical(eb[[5]], character(0)), "two letters is not a code")
check(identical(eb[[6]], character(0)), "three digits is not a code")
check(identical(eb[[7]], character(0)), "an underscore is not a hyphen")

# --- the same code twice in one string ---------------------------------
twice <- "ABC-1234 then ABC-1234 again"
check(identical(extract_codes(twice)[[1]], c("ABC-1234", "ABC-1234")),
      "repeated codes are all reported")
check(identical(replace_codes(twice, c("ABC-1234" = "ZZZ-0000")),
                "ZZZ-0000 then ZZZ-0000 again"),
      "every occurrence is replaced")

# --- an empty map changes nothing --------------------------------------
check(identical(replace_codes("ABC-1234 here", character(0)),
                "ABC-1234 here"),
      "an empty map is a no-op")
check(identical(replace_codes("no codes at all", c("ABC-1234" = "X")),
                "no codes at all"),
      "a map with no hits is a no-op")

# --- email edge cases ---------------------------------------------------
check(identical(mask_emails("plain text with an @ sign alone"),
                "plain text with an @ sign alone"),
      "a bare @ is not an address")
check(identical(mask_emails("user@localhost"), "user@localhost"),
      "a domain with no dot is not an address")
check(identical(mask_emails("a_b%c+d-e.f@sub.domain.co.uk"),
                "***@sub.domain.co.uk"),
      "every allowed local-part character is consumed")
check(identical(mask_emails("mail: one@a.io, two@b.io"),
                "mail: ***@a.io, ***@b.io"),
      "comma-separated addresses")

cat("ok\n")
