source("vecutil.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)

# --- equal lengths -----------------------------------------------------
stopifnot(identical(safe_add(1:3, 4:6), c(5L, 7L, 9L)))
check(isTRUE(all.equal(safe_add(c(1.5, 2.5), c(0.25, 0.5)), c(1.75, 3.0),
                       tolerance = 1e-9)), "equal-length double add")
check(identical(safe_add(integer(0), integer(0)), integer(0)), "empty + empty")

# --- scalar broadcast, both directions ---------------------------------
stopifnot(identical(safe_add(1:4, 10L), c(11L, 12L, 13L, 14L)))
stopifnot(identical(safe_add(10L, 1:4), c(11L, 12L, 13L, 14L)))

# --- pairwise with other binary functions ------------------------------
check(identical(pairwise(1:3, 2L, `*`), c(2L, 4L, 6L)), "pairwise multiply")
check(isTRUE(all.equal(pairwise(c(3, 1, 2), c(1, 5, 2), pmax), c(3, 5, 2),
                       tolerance = 1e-9)), "pairwise pmax")
check(identical(pairwise(1:3, 2L, function(a, b) a > b),
                c(FALSE, FALSE, TRUE)), "pairwise predicate")

# --- names come from the longer operand --------------------------------
r <- safe_add(c(a = 1, b = 2, c = 3), 10)
check(identical(names(r), c("a", "b", "c")), "names taken from longer x")
check(isTRUE(all.equal(unname(r), c(11, 12, 13), tolerance = 1e-9)),
      "broadcast values under names")

r2 <- safe_add(10, c(p = 1, q = 2))
check(identical(names(r2), c("p", "q")), "names taken from longer y")

r3 <- pairwise(c(a = 1, b = 2), c(x = 3, y = 4), `+`)
check(identical(names(r3), c("a", "b")), "equal lengths take x names")

check(is.null(names(safe_add(1:3, 4:6))), "unnamed stays unnamed")

# --- recycle_strict, the allowed cases ---------------------------------
check(identical(recycle_strict(1:3, 9L), rep(1:3, 3L)), "recycle 3 to 9")
check(identical(recycle_strict(c("a", "b"), 6L), rep(c("a", "b"), 3L)),
      "recycle character vector")
check(identical(recycle_strict(5L, 4L), rep(5L, 4L)), "recycle a scalar")

cat("ok\n")
