source("vecutil.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

# --- ambiguous recycling is refused, with the exact message ------------
check(identical(msg(safe_add(1:2, 1:4)), "length mismatch: 2 vs 4"),
      "2 vs 4 must be refused")
check(identical(msg(safe_add(1:4, 1:2)), "length mismatch: 4 vs 2"),
      "4 vs 2 must be refused")
check(identical(msg(pairwise(1:6, 1:4, `+`)), "length mismatch: 6 vs 4"),
      "6 vs 4 must be refused")

# --- zero length is only compatible with zero length -------------------
check(identical(msg(safe_add(integer(0), 1:3)), "length mismatch: 0 vs 3"),
      "empty vs 3 must be refused")
check(identical(msg(safe_add(integer(0), 1L)), "length mismatch: 0 vs 1"),
      "empty vs scalar must be refused")
check(identical(msg(safe_add(1:3, integer(0))), "length mismatch: 3 vs 0"),
      "3 vs empty must be refused")

# --- recycle_strict rejects partial recycling --------------------------
check(identical(msg(recycle_strict(1:2, 5L)), "cannot recycle length 2 to 5"),
      "2 to 5 must be refused")
check(identical(msg(recycle_strict(1:4, 6L)), "cannot recycle length 4 to 6"),
      "4 to 6 must be refused")
check(identical(msg(recycle_strict(integer(0), 3L)),
                "cannot recycle length 0 to 3"),
      "recycling an empty vector must be refused")

# --- zero-length targets keep the type ---------------------------------
check(identical(recycle_strict(integer(0), 0L), integer(0)), "0 to 0")
check(identical(recycle_strict(1:3, 0L), integer(0)), "n = 0 gives empty")
check(identical(recycle_strict(c("a", "b"), 0L), character(0)),
      "n = 0 keeps character type")
check(identical(recycle_strict(1:3, 3L), 1:3), "identity recycle")

cat("ok\n")
