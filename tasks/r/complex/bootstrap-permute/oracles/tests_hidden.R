source("resample.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

x <- c(2, 4, 4, 4, 5, 5, 7, 9)

# --- boot_ci ------------------------------------------------------------
b <- boot_ci(x, mean, 200, 42)
check(inherits(b, "boot_ci"), "boot_ci must set its class")
check(is.list(b), "a boot_ci is a list")
check(identical(names(b),
                c("estimate", "lower", "upper", "reps", "level",
                  "replicates")),
      "the element names, in order")
check(near(b$estimate, 5), "the estimate on the original data")
check(near(b$lower, 3.5), "the lower percentile bound for seed 42")
check(near(b$upper, 6.25), "the upper percentile bound for seed 42")
check(identical(b$reps, 200L), "reps is stored as an integer")
check(near(b$level, 0.95), "the level is stored")
check(identical(length(b$replicates), 200L), "one value per replicate")
check(is.double(b$replicates), "the replicates are doubles")
check(near(head(b$replicates, 5),
           c(3.375, 5.625, 4, 4.75, 5.125)),
      "the first five replicates follow the documented draw order")
check(b$lower <= b$estimate && b$estimate <= b$upper,
      "the estimate lies inside its own interval")

# --- the same seed reproduces the run ----------------------------------
check(identical(boot_ci(x, mean, 200, 42)$replicates, b$replicates),
      "the seed makes the whole run repeatable")
check(!near(boot_ci(x, mean, 200, 43)$lower, b$lower),
      "a different seed gives a different interval")

# --- the level changes the bounds, not the draws -----------------------
b90 <- boot_ci(x, mean, 200, 42, level = 0.90)
check(identical(b90$replicates, b$replicates),
      "the level must not change the random draws")
check(near(b90$lower, 3.74375), "the 90% lower bound")
check(near(b90$upper, 6), "the 90% upper bound")
check(b90$lower > b$lower, "a narrower level gives a narrower interval")
check(near(b90$level, 0.90), "the level is recorded")

# --- another statistic --------------------------------------------------
bm <- boot_ci(x, median, 100, 11)
check(near(bm$estimate, 4.5), "the median of the original data")
check(near(bm$lower, 4), "the median interval's lower bound")
check(near(bm$upper, 6.7625), "the median interval's upper bound")
check(identical(bm$reps, 100L), "a different replicate count")

# --- format_ci ----------------------------------------------------------
check(identical(format_ci(b), "5.000 [3.500, 6.250]"), "the default rendering")
check(identical(format_ci(b, 2), "5.00 [3.50, 6.25]"), "two digits")
check(is.character(format_ci(b)), "format_ci returns a string")
check(identical(length(format_ci(b)), 1L), "one string")

# --- perm_test ----------------------------------------------------------
xa <- c(1, 2, 3, 4, 5)
yb <- c(6, 7, 8, 9, 10)
gap <- function(a, b) mean(a) - mean(b)

p <- perm_test(xa, yb, gap, 200, 7)
check(inherits(p, "perm_test"), "perm_test must set its class")
check(identical(names(p),
                c("observed", "p_value", "reps", "alternative", "null_dist")),
      "the element names, in order")
check(near(p$observed, -5), "the observed difference in means")
check(near(p$p_value, 2 / 201), "the two-sided p-value for seed 7")
check(identical(p$reps, 200L), "reps is stored as an integer")
check(identical(p$alternative, "two.sided"), "the default alternative")
check(identical(length(p$null_dist), 200L), "one value per permutation")
check(is.double(p$null_dist), "the null distribution is doubles")
check(near(head(p$null_dist, 5), c(-0.6, 3.4, -1.8, 0.2, 0.6)),
      "the first five permutations follow the documented draw order")
check(p$p_value > 0, "the p-value can never be exactly zero")

# --- the alternatives -----------------------------------------------------
pg <- perm_test(xa, yb, gap, 200, 7, alternative = "greater")
pl <- perm_test(xa, yb, gap, 200, 7, alternative = "less")
check(identical(pg$null_dist, p$null_dist),
      "the alternative must not change the draws")
check(near(pg$p_value, 1), "nothing exceeds an observed value that low")
check(near(pl$p_value, 2 / 201), "the one-sided p-value in the other tail")
check(identical(pg$alternative, "greater"), "the alternative is recorded")
check(identical(pl$alternative, "less"), "and for the other tail")

# --- jackknife ------------------------------------------------------------
j <- jackknife(x, mean)
check(is.list(j), "jackknife must return a list")
check(identical(names(j), c("estimate", "bias", "se", "values")),
      "the element names, in order")
check(near(j$estimate, 5), "the estimate on the whole sample")
check(near(j$bias, 0), "the mean is unbiased, so the jackknife bias is zero")
check(near(j$se, sd(x) / sqrt(length(x))),
      "the jackknife standard error of the mean")
check(near(j$se, 0.755928946018), "the exact standard error")
check(identical(length(j$values), 8L), "one leave-one-out value per element")
check(near(j$values[1], mean(x[-1])), "the first leave-one-out value")
check(near(j$values[8], mean(x[-8])), "the last leave-one-out value")

jv <- jackknife(c(1, 2, 3, 4), var)
check(near(jv$estimate, 5 / 3), "the sample variance")
check(near(jv$bias, 0), "the sample variance is unbiased too")
check(near(jv$se, 1.154700538379), "the jackknife error of the variance")
check(near(jv$values, c(1, 7 / 3, 7 / 3, 1)), "the leave-one-out variances")

cat("ok\n")
