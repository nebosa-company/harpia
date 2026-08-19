source("mc.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# --- simulate_paths, pinned to the documented drawing recipe -----------
p <- simulate_paths(6, 4, 42)
check(is.matrix(p), "simulate_paths must return a matrix")
check(identical(dim(p), c(6L, 4L)), "n_steps rows by n_paths columns")
check(is.integer(p), "the running totals are integer")
check(identical(as.vector(p),
                c(-1L, -2L, -3L, -4L, -3L, -2L,
                   1L,  2L,  1L,  2L,  1L,  2L,
                  -1L,  0L, -1L, -2L, -1L,  0L,
                   1L,  2L,  1L,  0L, -1L, -2L)),
      "the exact walk for seed 42")

# --- it really is a +1/-1 walk ----------------------------------------
check(all(abs(p[1, ]) == 1L), "every path starts one step from zero")
check(all(abs(apply(p, 2L, diff)) == 1L), "every step moves by exactly one")

# --- the same seed gives the same batch --------------------------------
check(identical(simulate_paths(6, 4, 42), p), "the seed makes it repeatable")
check(!identical(simulate_paths(6, 4, 43), p), "a different seed differs")

# --- path_stats ---------------------------------------------------------
st <- path_stats(p)
check(is.data.frame(st), "path_stats must return a data frame")
check(identical(names(st), c("path", "final", "high", "low")),
      "path_stats column names")
check(identical(st$path, 1:4), "one row per path, numbered from one")
check(identical(st$final, c(-2L, 2L, 0L, -2L)), "the closing value per path")
check(identical(st$high, c(-1L, 2L, 0L, 2L)), "the maximum per path")
check(identical(st$low, c(-4L, 1L, -2L, -2L)), "the minimum per path")
check(all(vapply(st, is.integer, logical(1))), "every column is integer")
check(identical(rownames(st), as.character(1:4)), "default row names")

# --- ruin_rate ----------------------------------------------------------
check(is.double(ruin_rate(p, 1)), "ruin_rate must return a double")
check(near(ruin_rate(p, 1), 0.75), "three of four paths reach -1")
check(near(ruin_rate(p, 2), 0.75), "three of four paths reach -2")
check(near(ruin_rate(p, 3), 0.25), "one of four paths reaches -3")
check(near(ruin_rate(p, 5), 0), "no path reaches -5")
check(near(ruin_rate(p, 0), 0.75), "a barrier of zero counts paths at or below")

# --- a larger batch -----------------------------------------------------
p2 <- simulate_paths(50, 20, 7)
check(identical(dim(p2), c(50L, 20L)), "the larger batch's shape")
st2 <- path_stats(p2)
check(identical(st2$final,
                c(10L, 12L, 4L, 4L, 0L, -12L, -2L, 20L, -14L, 10L,
                  -6L, -8L, 10L, -4L, 4L, 2L, -8L, 4L, 8L, -2L)),
      "the closing values for seed 7")
check(near(ruin_rate(p2, 5), 0.4), "ruin rate at -5")
check(near(ruin_rate(p2, 10), 0.25), "ruin rate at -10")

# --- mc_pi --------------------------------------------------------------
est <- mc_pi(1000, 42)
check(is.double(est), "mc_pi must return a double")
check(near(est, 3.156), "the estimate for n = 1000, seed 42")
check(near(mc_pi(10000, 1), 3.1312), "the estimate for n = 10000, seed 1")
check(identical(mc_pi(1000, 42), mc_pi(1000, 42)), "mc_pi is repeatable")
check(!near(mc_pi(1000, 43), est), "a different seed gives a different draw")

cat("ok\n")
