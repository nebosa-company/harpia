source("factories.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
apply_all <- function(fs, v) vapply(fs, function(f) f(v), numeric(1))

# --- a batch of adders ---------------------------------------------------
adders <- build_adders(c(10, 20, 30))
check(is.list(adders), "build_adders must return a list")
check(identical(length(adders), 3L), "one function per setting")
check(all(vapply(adders, is.function, logical(1))), "every element is a function")
check(near(adders[[1]](0), 10), "the first adder adds the first setting")
check(near(adders[[2]](0), 20), "the second adder adds the second setting")
check(near(adders[[3]](0), 30), "the third adder adds the third setting")
check(near(apply_all(adders, 1), c(11, 21, 31)), "all three at once")
check(near(adders[[2]](5), 25), "an adder works on any input")

# --- calling them in a different order must not change anything --------
check(near(adders[[3]](0), 30), "the last adder")
check(near(adders[[1]](0), 10), "the first adder, called after the last")

# --- a batch of scalers --------------------------------------------------
scalers <- build_scalers(c(2, 3, 4))
check(identical(length(scalers), 3L), "one scaler per setting")
check(near(apply_all(scalers, 10), c(20, 30, 40)), "each scaler is distinct")
check(near(scalers[[1]](7), 14), "the first scaler")

# --- the factories still work on their own ------------------------------
f <- make_adder(5)
check(near(f(1), 6), "make_adder used directly")
g <- make_scaler(3)
check(near(g(4), 12), "make_scaler used directly")
p <- make_prefixer("id-")
check(identical(p("7"), "id-7"), "make_prefixer used directly")
cl <- make_clamp(0, 10)
check(near(cl(15), 10), "make_clamp used directly, above the range")
check(near(cl(-5), 0), "make_clamp used directly, below the range")
check(near(cl(4), 4), "make_clamp used directly, inside the range")

# --- a batch of one, and a batch of none --------------------------------
one <- build_adders(7)
check(identical(length(one), 1L), "a batch of one")
check(near(one[[1]](0), 7), "the single function is right")

check(identical(length(build_adders(numeric(0))), 0L), "an empty batch")
check(is.list(build_adders(numeric(0))), "an empty batch is still a list")
check(identical(length(build_scalers(numeric(0))), 0L), "an empty scaler batch")

# --- a longer batch ------------------------------------------------------
big <- build_scalers(1:5)
check(identical(length(big), 5L), "five scalers")
check(near(apply_all(big, 2), c(2, 4, 6, 8, 10)), "each of the five is distinct")

wide <- build_adders(c(0, 1, 2, 3, 4, 5, 6, 7))
check(near(apply_all(wide, 0), c(0, 1, 2, 3, 4, 5, 6, 7)),
      "an eight-wide batch stays distinct")

cat("ok\n")
