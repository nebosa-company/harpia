source("dates.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
D <- function(...) as.Date(c(...))

# --- NA propagates -----------------------------------------------------
withna <- D("2024-01-31", NA)
check(identical(format(month_end(withna)), c("2024-01-31", NA)),
      "month_end propagates NA")
check(identical(month_bucket(withna), c("2024-01", NA)),
      "month_bucket propagates NA")
check(identical(format(add_months(withna, 1)), c("2024-02-29", NA)),
      "add_months propagates NA")
check(identical(business_days(D(NA), as.Date("2024-01-31")), NA_integer_),
      "an NA start gives NA")
check(identical(business_days(as.Date("2024-01-01"), D(NA)), NA_integer_),
      "an NA end gives NA")

# --- reversed ranges count zero ---------------------------------------
check(identical(business_days(as.Date("2024-01-31"), as.Date("2024-01-01")),
                0L),
      "a reversed range counts zero, it does not error")
check(identical(business_days(as.Date("2024-01-07"), as.Date("2024-01-06")),
                0L),
      "a reversed weekend range counts zero")

# --- empty input -------------------------------------------------------
none <- as.Date(character(0))
check(identical(length(month_end(none)), 0L), "month_end on an empty vector")
check(identical(month_bucket(none), character(0)),
      "month_bucket on an empty vector")
check(identical(length(add_months(none, 1)), 0L),
      "add_months on an empty vector")
check(identical(business_days(none, none), integer(0)),
      "business_days on empty vectors")

# --- leap years and century boundaries --------------------------------
check(identical(format(month_end(as.Date("2000-02-05"))), "2000-02-29"),
      "2000 is a leap year")
check(identical(format(month_end(as.Date("1900-02-05"))), "1900-02-28"),
      "1900 is not a leap year")
check(identical(format(add_months(as.Date("2024-02-29"), 12)), "2025-02-28"),
      "29 February plus a year clamps")
check(identical(format(add_months(as.Date("2023-12-31"), 2)), "2024-02-29"),
      "crossing a year boundary into a leap February")
check(identical(format(add_months(as.Date("2024-01-15"), -13)), "2022-12-15"),
      "thirteen months back across two year boundaries")

# --- December buckets and month ends ----------------------------------
check(identical(month_bucket(as.Date("2024-12-31")), "2024-12"),
      "December bucket")
check(identical(format(month_end(as.Date("2024-12-01"))), "2024-12-31"),
      "December month end")

# --- longer business-day spans ----------------------------------------
check(identical(business_days(as.Date("2024-01-01"), as.Date("2024-12-31")),
                262L),
      "weekdays in the whole of 2024")
check(identical(business_days(as.Date("2024-02-01"), as.Date("2024-02-29")),
                21L),
      "weekdays in February 2024")
bb <- business_days(D("2024-01-01", "2024-02-01"),
                    D("2024-01-31", "2024-02-29"))
check(identical(bb, c(23L, 21L)), "paired vectors of equal length")

cat("ok\n")
