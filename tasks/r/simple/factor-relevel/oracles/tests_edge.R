source("levels.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

# --- levels declared out of natural order: codes lie, labels do not ----
h <- factor(c("10", "9", "10"), levels = c("10", "9"))
check(identical(as.integer(h), c(1L, 2L, 1L)), "fixture: codes are 1,2,1")
check(isTRUE(all.equal(numeric_codes(h), c(10, 9, 10), tolerance = 1e-9)),
      "numeric_codes must follow the labels")

# --- NA passes straight through ---------------------------------------
h2 <- factor(c("1.5", NA, "2.5"))
r <- numeric_codes(h2)
check(identical(length(r), 3L), "length preserved through NA")
check(is.na(r[2]), "NA element stays NA")
check(isTRUE(all.equal(r[c(1, 3)], c(1.5, 2.5), tolerance = 1e-9)),
      "decimal labels")

# --- bad labels are reported, not silently NA -------------------------
check(identical(msg(numeric_codes(factor(c("1", "x")))),
                "non-numeric level: x"), "non-numeric level rejected")
check(identical(msg(numeric_codes(factor(c("zz", "qq")))),
                "non-numeric level: qq"),
      "first offending label in level order is reported")
check(identical(msg(numeric_codes(c(1, 2))), "expected a factor"),
      "numeric_codes rejects non-factors")
check(identical(msg(level_counts(c("a", "b"))), "expected a factor"),
      "level_counts rejects non-factors")

# --- zero-count and unseen levels -------------------------------------
f0 <- set_order(c("low", "low"), c("low", "med", "high"))
check(identical(level_counts(f0)$count, c(2L, 0L, 0L)), "zero counts kept")

f1 <- set_order(c("a", "zzz", "b"), c("a", "b"))
check(identical(sum(is.na(f1)), 1L), "unlisted value became NA")
check(identical(level_counts(f1)$count, c(1L, 1L)), "NA is not counted")

fe <- set_order(character(0), c("a", "b"))
lce <- level_counts(fe)
check(identical(nrow(lce), 2L), "empty input still lists every level")
check(identical(lce$count, c(0L, 0L)), "empty input counts are zero")

fz <- factor(character(0))
lcz <- level_counts(fz)
check(identical(nrow(lcz), 0L), "a factor with no levels gives no rows")
check(is.character(lcz$level), "level column type survives an empty frame")
check(is.integer(lcz$count), "count column type survives an empty frame")

# --- a factor input is relevelled by label, not by code ---------------
src <- factor(c("high", "low"), levels = c("high", "low"))
f2 <- set_order(src, c("low", "med", "high"))
check(identical(as.character(f2), c("high", "low")), "labels drive the remap")
check(identical(levels(f2), c("low", "med", "high")), "new level order")
check(isTRUE(f2[2] < f2[1]), "ordering follows the new levels")

cat("ok\n")
