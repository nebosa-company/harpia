source("dates.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
D <- function(...) as.Date(c(...))

d <- D("2024-01-31", "2024-02-15", "2023-12-31", "2024-11-30", "2023-02-10")

# --- month_end ---------------------------------------------------------
me <- month_end(d)
check(inherits(me, "Date"), "month_end must return a Date vector")
check(identical(format(me),
                c("2024-01-31", "2024-02-29", "2023-12-31", "2024-11-30",
                  "2023-02-28")),
      "last day of each month, leap year included")
check(identical(length(me), 5L), "length preserved")

# --- month_bucket ------------------------------------------------------
mb <- month_bucket(d)
check(is.character(mb), "month_bucket must return character")
check(identical(mb, c("2024-01", "2024-02", "2023-12", "2024-11", "2023-02")),
      "YYYY-MM buckets with a zero-padded month")

# --- add_months --------------------------------------------------------
a1 <- add_months(d, 1)
check(inherits(a1, "Date"), "add_months must return a Date vector")
check(identical(format(a1),
                c("2024-02-29", "2024-03-15", "2024-01-31", "2024-12-30",
                  "2023-03-10")),
      "plus one month, clamped at February")

am1 <- add_months(d, -1)
check(identical(format(am1),
                c("2023-12-31", "2024-01-15", "2023-11-30", "2024-10-30",
                  "2023-01-10")),
      "minus one month")

check(identical(format(add_months(as.Date("2024-03-31"), -1)), "2024-02-29"),
      "31 March minus a month clamps to 29 February")
check(identical(format(add_months(as.Date("2024-01-31"), 13)), "2025-02-28"),
      "thirteen months across a non-leap February")
check(identical(format(add_months(as.Date("2023-05-15"), 0)), "2023-05-15"),
      "adding zero months is the identity")

av <- add_months(D("2024-01-31", "2024-01-31"), c(1, 2))
check(identical(format(av), c("2024-02-29", "2024-03-31")),
      "a vector of shifts")

# --- business_days -----------------------------------------------------
bd <- business_days(as.Date("2024-01-01"), as.Date("2024-01-31"))
check(is.integer(bd), "business_days must return integer")
check(identical(bd, 23L), "weekdays in January 2024")

check(identical(business_days(as.Date("2024-01-06"), as.Date("2024-01-07")),
                0L),
      "a Saturday-to-Sunday range has no business days")
check(identical(business_days(as.Date("2024-01-03"), as.Date("2024-01-03")),
                1L),
      "a single Wednesday counts as one")
check(identical(business_days(as.Date("2024-01-05"), as.Date("2024-01-08")),
                2L),
      "Friday through Monday counts the two weekdays")

bv <- business_days(D("2024-01-01", "2024-01-06"), as.Date("2024-01-07"))
check(identical(bv, c(5L, 0L)), "a length-1 `to` applies to every `from`")

cat("ok\n")
