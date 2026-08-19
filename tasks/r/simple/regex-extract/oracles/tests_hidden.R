source("logparse.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)

x <- c(
  "ticket ABC-1234 opened",
  "ABC-1234 and XYZ-0009 linked",
  "no code here",
  NA,
  "lowercase abc-1234 ignored",
  "ABCD-1234 and ABC-12345 are not codes",
  "trailing QRS-0001."
)

# --- extract_codes -----------------------------------------------------
ec <- extract_codes(x)
check(is.list(ec), "extract_codes must return a list")
check(identical(length(ec), 7L), "one element per input string")
check(is.null(names(ec)), "the result list is unnamed")
check(identical(ec[[1]], "ABC-1234"), "single code")
check(identical(ec[[2]], c("ABC-1234", "XYZ-0009")), "codes in order")
check(identical(ec[[3]], character(0)), "no codes gives character(0)")
check(identical(ec[[4]], character(0)), "NA gives character(0)")
check(identical(ec[[5]], character(0)), "lowercase is not a code")
check(identical(ec[[6]], character(0)),
      "a code inside a longer run of characters is not a code")
check(identical(ec[[7]], "QRS-0001"), "a trailing full stop still delimits")

# --- first_code --------------------------------------------------------
fc <- first_code(x)
check(is.character(fc), "first_code must return a character vector")
check(identical(length(fc), 7L), "one element per input string")
check(is.null(names(fc)), "first_code result is unnamed")
check(identical(fc, c("ABC-1234", "ABC-1234", NA, NA, NA, NA, "QRS-0001")),
      "first code per string")

# --- mask_emails -------------------------------------------------------
e <- c(
  "write to jane.doe@example.com now",
  "a@b.co and c.d+tag@mail.example.org",
  "no email",
  NA,
  "end x@y.com."
)
me <- mask_emails(e)
check(is.character(me), "mask_emails must return a character vector")
check(identical(me[1], "write to ***@example.com now"), "one address masked")
check(identical(me[2], "***@b.co and ***@mail.example.org"),
      "two addresses masked, domains kept")
check(identical(me[3], "no email"), "text without an address is untouched")
check(is.na(me[4]), "NA stays NA")
check(identical(me[5], "end ***@y.com."), "trailing punctuation is not domain")

# --- replace_codes -----------------------------------------------------
map <- c("ABC-1234" = "ABC-9999", "QRS-0001" = "QRS-0002")
rc <- replace_codes(x, map)
check(is.character(rc), "replace_codes must return a character vector")
check(identical(rc[1], "ticket ABC-9999 opened"), "mapped code replaced")
check(identical(rc[2], "ABC-9999 and XYZ-0009 linked"),
      "unmapped codes are left alone")
check(identical(rc[3], "no code here"), "text without codes is untouched")
check(is.na(rc[4]), "NA stays NA")
check(identical(rc[6], "ABCD-1234 and ABC-12345 are not codes"),
      "near-misses are never replaced")
check(identical(rc[7], "trailing QRS-0002."), "trailing code replaced")

cat("ok\n")
