source("factories.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# --- the settings are captured when the factory is called --------------
a <- 10
f <- make_adder(a)
a <- 99
check(near(f(0), 10),
      "an adder must keep the value it was built with, not track `a`")

k <- 2
g <- make_scaler(k)
k <- 100
check(near(g(3), 6), "a scaler must keep the value it was built with")

pfx <- "old-"
p <- make_prefixer(pfx)
pfx <- "new-"
check(identical(p("1"), "old-1"), "a prefixer must keep its prefix")

lo <- 0
hi <- 10
cl <- make_clamp(lo, hi)
lo <- 100
hi <- 200
check(near(cl(5), 5), "a clamp must keep both of its bounds")
check(near(cl(-1), 0), "the captured lower bound")
check(near(cl(50), 10), "the captured upper bound")

# --- a batch of prefixers ------------------------------------------------
prefixers <- build_prefixers(c("a-", "b-", "c-"))
check(identical(length(prefixers), 3L), "one prefixer per setting")
check(identical(vapply(prefixers, function(fn) fn("x"), character(1)),
                c("a-x", "b-x", "c-x")),
      "each prefixer keeps its own prefix")
check(identical(prefixers[[1]]("z"), "a-z"), "the first prefixer alone")

# --- a batch of clamps, which capture two settings each ----------------
clamps <- build_clamps(c(0, 10), c(5, 20))
check(identical(length(clamps), 2L), "one clamp per pair")
check(near(clamps[[1]](7), 5), "the first clamp's upper bound")
check(near(clamps[[1]](-3), 0), "the first clamp's lower bound")
check(near(clamps[[1]](3), 3), "the first clamp passes values through")
check(near(clamps[[2]](7), 10), "the second clamp's lower bound")
check(near(clamps[[2]](99), 20), "the second clamp's upper bound")
check(near(clamps[[2]](15), 15), "the second clamp passes values through")

# --- clamps work element-wise over a vector ----------------------------
check(near(clamps[[1]](c(-1, 3, 9)), c(0, 3, 5)), "vectorised clamping")
check(near(clamps[[2]](c(0, 15, 40)), c(10, 15, 20)),
      "vectorised clamping on the second clamp")

# --- three clamps, to rule out an off-by-one capture --------------------
three <- build_clamps(c(0, 5, 10), c(1, 6, 11))
check(near(vapply(three, function(fn) fn(100), numeric(1)), c(1, 6, 11)),
      "each clamp's upper bound")
check(near(vapply(three, function(fn) fn(-100), numeric(1)), c(0, 5, 10)),
      "each clamp's lower bound")

# --- an empty batch of every kind ---------------------------------------
check(identical(length(build_prefixers(character(0))), 0L),
      "an empty prefixer batch")
check(identical(length(build_clamps(numeric(0), numeric(0))), 0L),
      "an empty clamp batch")

# --- functions from one batch are independent of later batches ---------
first <- build_adders(c(1, 2))
second <- build_adders(c(100, 200))
check(near(first[[1]](0), 1), "the first batch is untouched by the second")
check(near(first[[2]](0), 2), "both members of the first batch survive")
check(near(second[[1]](0), 100), "the second batch is correct too")

# --- rebuilding over the same loop variable name -----------------------
fs <- list()
for (i in c(3, 6, 9)) {
  fs[[length(fs) + 1L]] <- make_adder(i)
}
check(near(vapply(fs, function(fn) fn(0), numeric(1)), c(3, 6, 9)),
      "hand-rolled loops over a factory must also stay distinct")

cat("ok\n")
