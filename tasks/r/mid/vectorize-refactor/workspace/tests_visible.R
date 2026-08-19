# Behavior these helpers must keep. Run with:
#   Rscript --vanilla tests_visible.R
source("series.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

x <- c(2, 4, 6, 8)

# running_total
check(near(running_total(x), c(2, 6, 12, 20)), "running_total")
check(identical(running_total(numeric(0)), numeric(0)), "running_total empty")
check(is.na(running_total(c(1, NA, 3))[3]), "running_total carries NA forward")

# pct_change
check(is.na(pct_change(x)[1]), "pct_change starts with NA")
check(near(pct_change(x)[2:4], c(1, 0.5, 1 / 3)), "pct_change values")
check(identical(pct_change(numeric(0)), numeric(0)), "pct_change empty")
check(is.na(pct_change(c(0, 5))[2]), "a zero denominator gives NA")

# rolling_mean
check(is.na(rolling_mean(x, 2)[1]), "the first window is incomplete")
check(near(rolling_mean(x, 2)[2:4], c(3, 5, 7)), "rolling_mean values")
check(all(is.na(rolling_mean(x, 9))), "k larger than the input")
check(near(rolling_mean(x, 1), x), "a window of one is the input")
check(is.na(rolling_mean(c(1, NA, 3), 2)[3]), "a window with NA is NA")
check(inherits(try(rolling_mean(x, 0), silent = TRUE), "try-error"),
      "k below one is an error")

# zscore
check(near(zscore(x), (x - 5) / sd(x)), "zscore values")
check(all(is.na(zscore(c(3, 3, 3)))), "no spread gives NA")
check(all(is.na(zscore(c(7)))), "a single value gives NA")

cat("ok\n")
