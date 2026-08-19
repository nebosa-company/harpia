source("series.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

# --- the preserved behavior, on longer inputs --------------------------
x <- c(3, 1, 4, 1, 5, 9, 2, 6)
check(near(running_total(x), c(3, 4, 8, 9, 14, 23, 25, 31)), "running_total")
check(is.double(running_total(x)), "running_total returns doubles")
check(near(running_total(c(-1, -2, -3)), c(-1, -3, -6)), "negative values")

pc <- pct_change(x)
check(is.na(pc[1]), "pct_change starts with NA")
check(near(pc[2:4], c(-2 / 3, 3, -0.75)), "pct_change values")
check(identical(length(pc), 8L), "pct_change keeps the length")

rm3 <- rolling_mean(x, 3)
check(all(is.na(rm3[1:2])), "the first two windows are incomplete")
check(near(rm3[3:8], c(8 / 3, 2, 10 / 3, 5, 16 / 3, 17 / 3)),
      "rolling_mean over a window of three")
rm8 <- rolling_mean(x, 8)
check(all(is.na(rm8[1:7])), "only the final window is complete")
check(near(rm8[8], mean(x)), "a window covering everything")

zs <- zscore(x)
check(near(zs, (x - mean(x)) / sd(x)), "zscore values")
check(near(sum(zs), 0), "z-scores sum to zero")

# --- rolling_max --------------------------------------------------------
mx <- rolling_max(c(1, 5, 2, 8, 3), 3)
check(is.double(mx), "rolling_max returns doubles")
check(identical(length(mx), 5L), "rolling_max keeps the length")
check(all(is.na(mx[1:2])), "the first two windows are incomplete")
check(near(mx[3:5], c(5, 8, 8)), "rolling_max values")

check(near(rolling_max(x, 1), x), "a window of one is the input")
mx8 <- rolling_max(x, 8)
check(all(is.na(mx8[1:7])), "only the final max window is complete")
check(near(mx8[8], 9), "a window covering everything")
check(near(rolling_max(c(4, 2, 7, 1), 2)[2:4], c(4, 7, 7)),
      "a window of two")
check(all(is.na(rolling_max(c(1, 2), 5))), "k larger than the input")
check(is.na(rolling_max(c(1, NA, 3), 2)[2]), "a window with NA is NA")
check(is.na(rolling_max(c(1, NA, 3), 2)[3]), "and the next window too")
check(identical(msg(rolling_max(x, 0)), "k must be at least 1"),
      "k below one is refused")

# --- ewma ----------------------------------------------------------------
e <- ewma(c(1, 2, 3), 0.5)
check(is.double(e), "ewma returns doubles")
check(identical(length(e), 3L), "ewma keeps the length")
check(near(e, c(1, 1.5, 2.25)), "the exponentially weighted average")

check(near(ewma(c(10, 20), 1), c(10, 20)),
      "alpha of one follows the input exactly")
check(near(ewma(c(4, 4, 4), 0.3), c(4, 4, 4)),
      "a constant series is its own average")
check(near(ewma(c(0, 10, 0, 10), 0.25),
           c(0, 2.5, 1.875, 3.90625)), "a longer smoothing")
check(near(ewma(5, 0.5), 5), "a single point is itself")
check(identical(ewma(numeric(0), 0.5), numeric(0)), "an empty series")
check(identical(msg(ewma(c(1, 2), 0)), "alpha must be in (0, 1]"),
      "alpha of zero is refused")
check(identical(msg(ewma(c(1, 2), 1.5)), "alpha must be in (0, 1]"),
      "alpha above one is refused")

cat("ok\n")
