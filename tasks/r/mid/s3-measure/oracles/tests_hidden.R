source("measure.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

m <- measure(c(1.5, 2, 3.25), "kg")

# --- representation -----------------------------------------------------
check(inherits(m, "measure"), "the constructor must set the class")
check(identical(class(m), "measure"), "class is exactly \"measure\"")
check(is.double(unclass(m)), "the payload is a double vector")
check(identical(unit_of(m), "kg"), "unit_of returns the unit")
check(identical(length(m), 3L), "length works without a method")
check(near(as.numeric(m), c(1.5, 2, 3.25)), "the values are kept")
check(identical(sort(names(attributes(m))), c("class", "unit")),
      "no attributes beyond unit and class")

im <- measure(1:3, "m")
check(is.double(unclass(im)), "an integer input is stored as double")

# --- format -------------------------------------------------------------
f <- format(m)
check(is.character(f), "format must return a character vector")
check(identical(f, c("1.50 kg", "2.00 kg", "3.25 kg")), "two decimals")
check(identical(format(m, digits = 3),
                c("1.500 kg", "2.000 kg", "3.250 kg")),
      "the digits argument is honoured")
check(identical(format(m, digits = 0), c("2 kg", "2 kg", "3 kg")),
      "zero decimals")

# --- print --------------------------------------------------------------
out <- capture.output(print(m))
check(identical(out, c("<measure [3] kg>", "1.50 kg", "2.00 kg", "3.25 kg")),
      "print output, line for line")
check(identical(capture.output(invisible(print(m)))[1], "<measure [3] kg>"),
      "the header line")
r <- withVisible(print(m))
check(identical(r$visible, FALSE), "print returns its argument invisibly")
check(inherits(r$value, "measure"), "print returns the measure itself")

# --- summary ------------------------------------------------------------
s <- summary(m)
check(inherits(s, "summary_measure"), "summary sets its own class")
check(identical(names(s), c("n", "mean", "min", "max", "unit")),
      "summary element names, in order")
check(identical(s$n, 3L), "n is an integer count")
check(near(s$mean, 2.25), "mean")
check(near(s$min, 1.5), "min")
check(near(s$max, 3.25), "max")
check(identical(s$unit, "kg"), "the unit travels with the summary")

so <- capture.output(print(s))
check(identical(so, c("measure summary (kg)",
                      "  n    : 3",
                      "  mean : 2.25",
                      "  min  : 1.50",
                      "  max  : 3.25")),
      "summary print output, line for line")

# --- addition -----------------------------------------------------------
a <- m + measure(c(1, 1, 1), "kg")
check(inherits(a, "measure"), "measure + measure is a measure")
check(identical(unit_of(a), "kg"), "the unit survives addition")
check(near(as.numeric(a), c(2.5, 3, 4.25)), "values added element-wise")

b <- m + 1
check(inherits(b, "measure"), "measure + number is a measure")
check(near(as.numeric(b), c(2.5, 3, 4.25)), "a number is added to each value")
check(identical(unit_of(b), "kg"), "the unit is kept")

d <- 1 + m
check(inherits(d, "measure"), "number + measure is a measure")
check(near(as.numeric(d), c(2.5, 3, 4.25)), "addition is symmetric")
check(identical(unit_of(d), "kg"), "the unit is recovered from the right side")

# --- subsetting ---------------------------------------------------------
sub <- m[2:3]
check(inherits(sub, "measure"), "subsetting keeps the class")
check(identical(unit_of(sub), "kg"), "subsetting keeps the unit")
check(near(as.numeric(sub), c(2, 3.25)), "the selected values")
check(identical(length(sub), 2L), "the selected length")

cat("ok\n")
