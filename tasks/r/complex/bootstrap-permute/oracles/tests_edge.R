source("resample.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

x <- c(2, 4, 4, 4, 5, 5, 7, 9)
gap <- function(a, b) mean(a) - mean(b)

# --- sample validation ---------------------------------------------------
check(identical(msg(boot_ci(numeric(0), mean, 10, 1)),
                "x must be a non-empty numeric vector"),
      "an empty sample is refused")
check(identical(msg(boot_ci("a", mean, 10, 1)),
                "x must be a non-empty numeric vector"),
      "a character sample is refused")
check(identical(msg(jackknife(character(0), mean)),
                "x must be a non-empty numeric vector"),
      "jackknife refuses an empty sample")
check(identical(msg(perm_test(numeric(0), c(1, 2), gap, 10, 1)),
                "x must be a non-empty numeric vector"),
      "perm_test refuses an empty first sample")
check(identical(msg(perm_test(c(1, 2), numeric(0), gap, 10, 1)),
                "x must be a non-empty numeric vector"),
      "perm_test refuses an empty second sample")

# --- reps validation -----------------------------------------------------
check(identical(msg(boot_ci(x, mean, 0, 1)),
                "reps must be a positive whole number"),
      "zero replicates is refused")
check(identical(msg(boot_ci(x, mean, -5, 1)),
                "reps must be a positive whole number"),
      "a negative replicate count is refused")
check(identical(msg(boot_ci(x, mean, 2.5, 1)),
                "reps must be a positive whole number"),
      "a fractional replicate count is refused")
check(identical(msg(boot_ci(x, mean, c(10, 20), 1)),
                "reps must be a positive whole number"),
      "two replicate counts are refused")
check(identical(msg(perm_test(c(1, 2), c(3, 4), gap, 0, 1)),
                "reps must be a positive whole number"),
      "perm_test checks reps too")

# --- level validation ----------------------------------------------------
check(identical(msg(boot_ci(x, mean, 10, 1, level = 0)),
                "level must be between 0 and 1"), "a level of zero")
check(identical(msg(boot_ci(x, mean, 10, 1, level = 1)),
                "level must be between 0 and 1"), "a level of one")
check(identical(msg(boot_ci(x, mean, 10, 1, level = 95)),
                "level must be between 0 and 1"), "a level given as a percent")
check(identical(msg(boot_ci(x, mean, 10, 1, level = NA)),
                "level must be between 0 and 1"), "an NA level")

# --- alternative validation ----------------------------------------------
check(identical(msg(perm_test(c(1, 2), c(3, 4), gap, 10, 1,
                              alternative = "sideways")),
                "alternative must be two.sided, greater or less"),
      "an unknown alternative is refused")
check(identical(msg(perm_test(c(1, 2), c(3, 4), gap, 10, 1,
                              alternative = c("less", "greater"))),
                "alternative must be two.sided, greater or less"),
      "two alternatives are refused")

# --- format_ci validation ------------------------------------------------
check(identical(msg(format_ci(list(estimate = 1, lower = 0, upper = 2))),
                "expected a boot_ci object"),
      "a bare list is not a boot_ci")
check(identical(msg(format_ci(42)), "expected a boot_ci object"),
      "a number is not a boot_ci")

# --- jackknife needs at least two values --------------------------------
check(identical(msg(jackknife(5, mean)), "x must have at least two values"),
      "one observation cannot be jackknifed")
j2 <- jackknife(c(2, 6), mean)
check(identical(length(j2$values), 2L), "two observations are enough")
check(near(j2$values, c(6, 2)), "each leave-one-out value")
check(near(j2$estimate, 4), "the estimate")
check(near(j2$bias, 0), "still unbiased")
check(near(j2$se, sd(c(2, 6)) / sqrt(2)), "the standard error of two points")

# --- a single replicate ---------------------------------------------------
b1 <- boot_ci(x, mean, 1, 3)
check(identical(b1$reps, 1L), "one replicate is allowed")
check(identical(length(b1$replicates), 1L), "one replicate value")
check(near(b1$lower, b1$upper),
      "one replicate collapses the interval to a point")
check(near(b1$lower, b1$replicates[1]), "and that point is the replicate")

p1 <- perm_test(c(1, 2), c(8, 9), gap, 1, 3)
check(identical(length(p1$null_dist), 1L), "one permutation")
check(p1$p_value >= 0.5, "with one permutation the p-value is 1/2 or 1")

# --- a constant sample ---------------------------------------------------
flat <- boot_ci(rep(4, 6), mean, 50, 2)
check(near(flat$estimate, 4), "a constant sample's estimate")
check(near(flat$lower, 4) && near(flat$upper, 4),
      "every resample of a constant sample gives the same value")
check(identical(format_ci(flat), "4.000 [4.000, 4.000]"),
      "a degenerate interval still renders")

# --- a sample of one, for the bootstrap ---------------------------------
one <- boot_ci(7, mean, 20, 5)
check(near(one$estimate, 7), "a single observation is its own estimate")
check(near(one$lower, 7) && near(one$upper, 7),
      "there is nothing to resample but itself")
check(identical(length(one$replicates), 20L), "the replicates are still made")

# --- the two samples may differ in length -------------------------------
uneven <- perm_test(c(1, 2, 3), c(10, 11), gap, 100, 9)
check(near(uneven$observed, mean(c(1, 2, 3)) - mean(c(10, 11))),
      "the observed statistic with uneven samples")
check(identical(length(uneven$null_dist), 100L), "every permutation ran")
check(uneven$p_value > 0 && uneven$p_value <= 1,
      "the p-value stays in range")
check(identical(uneven$null_dist,
                perm_test(c(1, 2, 3), c(10, 11), gap, 100, 9)$null_dist),
      "and it is repeatable")

# --- the split really is a partition ------------------------------------
sizes <- perm_test(c(1, 2, 3), c(10, 11), function(a, b) length(a) * 100 +
                     length(b), 25, 4)
check(near(sizes$null_dist, rep(302, 25)),
      "every permutation gives three values to x and two to y")

sums <- perm_test(c(1, 2, 3), c(10, 11), function(a, b) sum(a) + sum(b),
                  25, 4)
check(near(sums$null_dist, rep(27, 25)),
      "every permutation uses each pooled value exactly once")

# --- reseeding leaves no trace between calls ---------------------------
before <- boot_ci(x, mean, 50, 42)$replicates
ignored <- perm_test(c(1, 2), c(3, 4), gap, 30, 99)
after <- boot_ci(x, mean, 50, 42)$replicates
check(identical(before, after), "each call reseeds, so calls cannot interfere")

cat("ok\n")
