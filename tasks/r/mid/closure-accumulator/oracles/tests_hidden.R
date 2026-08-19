source("accum.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# --- make_accumulator ---------------------------------------------------
acc <- make_accumulator()
check(is.list(acc), "make_accumulator must return a list")
check(identical(names(acc), c("add", "total", "count", "history", "reset")),
      "the accumulator's element names, in order")
check(all(vapply(acc, is.function, logical(1))), "every element is a function")

check(near(acc$total(), 0), "the total starts at zero")
check(identical(acc$count(), 0L), "the count starts at zero")
check(identical(acc$history(), numeric(0)), "the history starts empty")
check(is.double(acc$history()), "the history is a double vector")

acc$add(5)
acc$add(3)
check(near(acc$total(), 8), "the running total")
check(identical(acc$count(), 2L), "two values added")
check(near(acc$history(), c(5, 3)), "the history in order")

# --- add takes a vector and returns invisibly ---------------------------
r <- withVisible(acc$add(c(1, 2, 3)))
check(identical(r$visible, FALSE), "add returns invisibly")
check(near(r$value, 14), "add returns the new total")
check(identical(acc$count(), 5L), "elements are counted, not calls")
check(near(acc$history(), c(5, 3, 1, 2, 3)), "every element joins the history")

# --- a non-zero start ---------------------------------------------------
acc2 <- make_accumulator(100)
check(near(acc2$total(), 100), "the total starts at `start`")
acc2$add(1)
check(near(acc2$total(), 101), "adding to a non-zero start")

# --- the two accumulators are completely independent -------------------
check(near(acc$total(), 14), "the first accumulator is untouched")
check(identical(acc2$count(), 1L), "the second has its own count")
check(near(acc2$history(), 1), "the second has its own history")

# --- reset --------------------------------------------------------------
rr <- withVisible(acc$reset())
check(identical(rr$visible, FALSE), "reset returns invisibly")
check(is.null(rr$value), "reset returns NULL")
check(near(acc$total(), 0), "reset restores the starting total")
check(identical(acc$count(), 0L), "reset empties the count")
check(identical(acc$history(), numeric(0)), "reset empties the history")
acc2$reset()
check(near(acc2$total(), 100), "reset restores a non-zero start")

# --- make_tally ---------------------------------------------------------
tal <- make_tally()
check(identical(names(tal), c("hit", "counts", "top")),
      "the tally's element names, in order")
check(identical(length(tal$counts()), 0L), "an untouched tally counts nothing")
check(is.integer(tal$counts()), "counts is an integer vector")
check(identical(tal$top(3), character(0)), "top of an empty tally")

for (lab in c("b", "a", "b", "c", "b")) tal$hit(lab)
cn <- tal$counts()
check(is.integer(cn), "counts stays integer")
check(identical(names(cn), c("a", "b", "c")), "counts sorted by label")
check(identical(unname(cn), c(1L, 3L, 1L)), "the counts themselves")

h <- withVisible(tal$hit("a"))
check(identical(h$visible, FALSE), "hit returns invisibly")
check(identical(h$value, 2L), "hit returns the new count as an integer")

check(identical(tal$top(2), c("b", "a")),
      "most frequent first, ties broken by label")
check(identical(tal$top(10), c("b", "a", "c")),
      "asking for more labels than exist")

tal2 <- make_tally()
check(identical(length(tal2$counts()), 0L), "a fresh tally is empty")
check(identical(unname(tal$counts()), c(2L, 3L, 1L)),
      "the first tally is untouched by the second")

# --- make_limited -------------------------------------------------------
lim <- make_limited(10)
check(identical(names(lim), c("add", "total", "rejected")),
      "the limited accumulator's element names, in order")
check(near(lim$total(), 0), "the total starts at zero")
check(identical(lim$rejected(), 0L), "nothing has been rejected yet")

lim$add(6)
check(near(lim$total(), 6), "a permitted add")
lr <- withVisible(lim$add(4))
check(identical(lr$visible, FALSE), "add returns invisibly")
check(near(lr$value, 10), "landing exactly on the cap is allowed")
check(near(lim$total(), 10), "the total reached the cap")
check(identical(lim$rejected(), 0L), "reaching the cap is not a rejection")

cat("ok\n")
