source("mc.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# --- a single step still gives a matrix, not a vector ------------------
p1 <- simulate_paths(1, 3, 99)
check(is.matrix(p1), "one step must still give a matrix")
check(identical(dim(p1), c(1L, 3L)), "one row, three columns")
check(is.integer(p1), "still integer")
check(identical(as.vector(p1), c(1L, -1L, 1L)), "the exact one-step draw")

s1 <- path_stats(p1)
check(identical(s1$path, 1:3), "three paths")
check(identical(s1$final, c(1L, -1L, 1L)), "one step is also the final value")
check(identical(s1$high, c(1L, -1L, 1L)), "high equals the single value")
check(identical(s1$low, c(1L, -1L, 1L)), "low equals the single value")

# --- a single path still gives a matrix --------------------------------
pc <- simulate_paths(4, 1, 5)
check(is.matrix(pc), "one path must still give a matrix")
check(identical(dim(pc), c(4L, 1L)), "four rows, one column")
check(identical(as.vector(pc), c(1L, 0L, -1L, -2L)), "the exact single walk")

sc <- path_stats(pc)
check(identical(nrow(sc), 1L), "one row of statistics")
check(identical(sc$final, -2L), "the closing value")
check(identical(sc$high, 1L), "the maximum")
check(identical(sc$low, -2L), "the minimum")
check(near(ruin_rate(pc, 2), 1), "the one path reaches the barrier")
check(near(ruin_rate(pc, 3), 0), "the one path never reaches -3")

# --- an empty batch ------------------------------------------------------
p0 <- simulate_paths(4, 0, 1)
check(is.matrix(p0), "no paths still gives a matrix")
check(identical(dim(p0), c(4L, 0L)), "four rows, no columns")
check(near(ruin_rate(p0, 1), 0), "no paths means a ruin rate of zero")
check(!is.nan(ruin_rate(p0, 1)), "the empty case must not be NaN")

s0 <- path_stats(p0)
check(identical(nrow(s0), 0L), "no paths, no rows of statistics")
check(identical(names(s0), c("path", "final", "high", "low")),
      "the empty result keeps its columns")
check(is.integer(s0$final), "the empty result keeps its column types")

# --- the draw is one block, not one call per path ---------------------
steps_of <- function(m) {
  as.vector(apply(m, 2L, function(col) c(col[1], diff(col))))
}
wide <- simulate_paths(2, 12, 42)
tall <- simulate_paths(12, 2, 42)
check(identical(dim(wide), c(2L, 12L)), "the wide batch's shape")
check(identical(dim(tall), c(12L, 2L)), "the tall batch's shape")
check(identical(steps_of(wide), steps_of(tall)),
      "24 draws from seed 42 are one block, however the matrix is shaped")
check(identical(steps_of(wide), steps_of(simulate_paths(2, 12, 42))),
      "the step stream is repeatable")

# --- mc_pi corner cases -------------------------------------------------
tiny <- mc_pi(4, 3)
check(is.double(tiny), "mc_pi returns a double even for a tiny n")
check(near(tiny, 3), "the exact estimate for n = 4, seed 3")
check(mc_pi(1000, 42) >= 0 && mc_pi(1000, 42) <= 4,
      "an estimate always lies between 0 and 4")
check(near(mc_pi(1000, 7), mc_pi(1000, 7)), "repeatable for any seed")

# --- drawing x before y matters ----------------------------------------
set.seed(11)
first <- runif(50)
second <- runif(50)
check(near(mc_pi(50, 11), 4 * mean(first^2 + second^2 <= 1)),
      "x is drawn before y, in two separate calls")

# --- reseeding leaves no trace between calls --------------------------
a <- simulate_paths(6, 4, 42)
ignored <- mc_pi(500, 1)
b <- simulate_paths(6, 4, 42)
check(identical(a, b), "each function reseeds, so calls cannot interfere")

cat("ok\n")
