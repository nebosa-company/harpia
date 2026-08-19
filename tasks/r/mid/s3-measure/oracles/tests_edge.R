source("measure.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

# --- the constructor validates -----------------------------------------
check(identical(msg(measure("x", "kg")), "value must be numeric"),
      "a character payload is refused")
check(identical(msg(measure(TRUE, "kg")), "value must be numeric"),
      "a logical payload is refused")
check(identical(msg(measure(1, "")),
                "unit must be a single non-empty string"),
      "an empty unit is refused")
check(identical(msg(measure(1, c("a", "b"))),
                "unit must be a single non-empty string"),
      "two units are refused")
check(identical(msg(measure(1, NA_character_)),
                "unit must be a single non-empty string"),
      "an NA unit is refused")
check(identical(msg(measure(1, 5)),
                "unit must be a single non-empty string"),
      "a numeric unit is refused")

# --- adding across units is an error -----------------------------------
kg <- measure(c(1, 2), "kg")
lb <- measure(c(1, 2), "lb")
check(identical(msg(kg + lb), "unit mismatch: kg vs lb"),
      "mismatched units are refused")
check(identical(msg(lb + kg), "unit mismatch: lb vs kg"),
      "the message reports the operands in order")
check(is.na(msg(kg + measure(3, "kg"))),
      "a length-1 measure recycles against a longer one")
check(near(as.numeric(kg + measure(3, "kg")), c(4, 5)), "recycled addition")

# --- a zero-length measure ---------------------------------------------
z <- measure(numeric(0), "kg")
check(identical(length(z), 0L), "length zero")
check(identical(format(z), character(0)), "format gives character(0)")
check(identical(capture.output(print(z)), "<measure [0] kg>"),
      "only the header line is printed")
sz <- summary(z)
check(identical(sz$n, 0L), "n is zero")
check(is.na(sz$mean) && is.na(sz$min) && is.na(sz$max),
      "the statistics are NA, never Inf or NaN")
check(is.double(sz$mean), "mean stays a double NA")
check(identical(sz$unit, "kg"), "the unit is still reported")
check(identical(capture.output(print(sz)),
                c("measure summary (kg)",
                  "  n    : 0",
                  "  mean : NA",
                  "  min  : NA",
                  "  max  : NA")),
      "an empty summary prints NA for each statistic")

# --- NA values ----------------------------------------------------------
withna <- measure(c(1, NA, 3), "m")
check(identical(summary(withna)$n, 2L), "n counts only the real values")
check(near(summary(withna)$mean, 2), "the mean skips NA")
check(near(summary(withna)$min, 1), "the min skips NA")
check(near(summary(withna)$max, 3), "the max skips NA")
fn <- format(withna)
check(identical(length(fn), 3L), "format keeps every element")
check(identical(fn[2], "NA m"), "an NA value formats as NA plus the unit")

# --- an all-NA measure --------------------------------------------------
allna <- measure(c(NA_real_, NA_real_), "s")
check(identical(summary(allna)$n, 0L), "no real values")
check(is.na(summary(allna)$max), "max of nothing is NA")

# --- a single value -----------------------------------------------------
one <- measure(2.5, "L")
check(identical(capture.output(print(one)),
                c("<measure [1] L>", "2.50 L")), "a one-element measure")
check(identical(capture.output(print(summary(one))),
                c("measure summary (L)",
                  "  n    : 1",
                  "  mean : 2.50",
                  "  min  : 2.50",
                  "  max  : 2.50")),
      "a one-element summary")

# --- subsetting corner cases -------------------------------------------
m <- measure(c(1, 2, 3), "kg")
e <- m[integer(0)]
check(inherits(e, "measure"), "an empty subset is still a measure")
check(identical(length(e), 0L), "an empty subset has no values")
check(identical(unit_of(e), "kg"), "an empty subset keeps its unit")

neg <- m[-1]
check(inherits(neg, "measure"), "negative subsetting keeps the class")
check(near(as.numeric(neg), c(2, 3)), "negative subsetting drops the first")

lg <- m[c(TRUE, FALSE, TRUE)]
check(near(as.numeric(lg), c(1, 3)), "logical subsetting")
check(identical(unit_of(lg), "kg"), "logical subsetting keeps the unit")

# --- chaining -----------------------------------------------------------
chained <- (m + 1)[2:3]
check(inherits(chained, "measure"), "adding then subsetting stays a measure")
check(near(as.numeric(chained), c(3, 4)), "chained values")

cat("ok\n")
