source("accum.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

# --- going over the cap leaves the state alone -------------------------
lim <- make_limited(10)
lim$add(6)
check(identical(msg(lim$add(5)), "cap 10 exceeded"),
      "exceeding the cap raises the documented message")
check(near(lim$total(), 6), "a refused add must not move the total")
check(identical(lim$rejected(), 1L), "the rejection is counted")
check(identical(msg(lim$add(5)), "cap 10 exceeded"), "refused a second time")
check(identical(lim$rejected(), 2L), "rejections accumulate")
check(near(lim$total(), 6), "still untouched after two refusals")
lim$add(4)
check(near(lim$total(), 10), "a permitted add still works afterwards")
check(identical(lim$rejected(), 2L), "a success is not a rejection")

frac <- make_limited(2.5)
frac$add(2.5)
check(near(frac$total(), 2.5), "a fractional cap can be reached exactly")
check(identical(msg(frac$add(0.1)), "cap 2.5 exceeded"),
      "a fractional cap in the message")

neg <- make_limited(0)
check(is.na(msg(neg$add(-1))), "a negative add can stay under the cap")
check(near(neg$total(), -1), "the total may go negative")

lim2 <- make_limited(10)
check(identical(lim2$rejected(), 0L),
      "a second limited accumulator has its own rejection count")
check(near(lim2$total(), 0), "and its own total")

check(identical(msg(lim2$add("x")), "add expects a single number"),
      "a non-numeric add is refused")
check(identical(msg(lim2$add(c(1, 2))), "add expects a single number"),
      "a vector add is refused")

# --- accumulator input validation --------------------------------------
acc <- make_accumulator()
check(identical(msg(acc$add("x")), "add expects a numeric value"),
      "a character add is refused")
check(identical(msg(acc$add(TRUE)), "add expects a numeric value"),
      "a logical add is refused")
check(identical(acc$count(), 0L), "a refused add changes nothing")
check(is.na(msg(acc$add(numeric(0)))), "an empty add is allowed")
check(identical(acc$count(), 0L), "an empty add adds no elements")
check(near(acc$total(), 0), "an empty add leaves the total alone")

acc$add(c(-1, 2.5))
check(near(acc$total(), 1.5), "negative and fractional values")
check(identical(acc$count(), 2L), "both elements counted")
check(near(acc$history(), c(-1, 2.5)), "both elements recorded")

# --- the history is a value, not a live view --------------------------
snapshot <- acc$history()
acc$add(99)
check(near(snapshot, c(-1, 2.5)), "an earlier history is not mutated")
check(identical(acc$count(), 3L), "the accumulator did move on")

# --- three accumulators stay independent -------------------------------
a1 <- make_accumulator(1)
a2 <- make_accumulator(2)
a3 <- make_accumulator(3)
a2$add(10)
check(near(c(a1$total(), a2$total(), a3$total()), c(1, 12, 3)),
      "only the accumulator that was used moved")
a1$reset()
check(near(a2$total(), 12), "resetting one does not reset the others")

# --- tally validation and ordering -------------------------------------
tal <- make_tally()
check(identical(msg(tal$hit(1)), "hit expects a single label"),
      "a numeric label is refused")
check(identical(msg(tal$hit(c("a", "b"))), "hit expects a single label"),
      "two labels are refused")
check(identical(msg(tal$hit(NA_character_)), "hit expects a single label"),
      "an NA label is refused")
check(identical(length(tal$counts()), 0L), "a refused hit records nothing")

for (lab in c("pear", "apple", "pear", "fig", "apple")) tal$hit(lab)
check(identical(names(tal$counts()), c("apple", "fig", "pear")),
      "counts are sorted by label, not by insertion")
check(identical(unname(tal$counts()), c(2L, 1L, 2L)), "the counts")
check(identical(tal$top(2), c("apple", "pear")),
      "a tie between the leaders is broken by label")
check(identical(tal$top(1), "apple"), "the single leader")
check(identical(tal$top(0), character(0)), "top(0) is empty")
check(identical(tal$top(-1), character(0)), "a negative n is empty")
check(identical(tal$top(99), c("apple", "pear", "fig")),
      "more than exist gives all of them, still ordered")

single <- make_tally()
single$hit("only")
check(identical(single$counts(), c(only = 1L)), "a single labelled count")
check(identical(single$top(5), "only"), "a single label tops the list")

cat("ok\n")
