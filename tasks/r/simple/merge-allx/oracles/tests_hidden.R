source("joins.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

mkx <- function() {
  data.frame(
    cust = c("c3", "c1", "c9", "c1", "c2"),
    amount = c(10, 20, 30, 40, 50),
    region = c("N", "S", "N", "E", "W"),
    stringsAsFactors = FALSE
  )
}
mky <- function() {
  data.frame(
    cust = c("c1", "c2", "c3"),
    name = c("Alice", "Bob", "Carol"),
    region = c("north", "south", "east"),
    tier = c(1L, 2L, 3L),
    stringsAsFactors = FALSE
  )
}

j <- left_join_df(mkx(), mky(), "cust")

# --- shape --------------------------------------------------------------
check(is.data.frame(j), "left_join_df must return a data frame")
check(identical(nrow(j), 5L), "one row per row of x, never more")
check(identical(names(j),
                c("cust", "amount", "region", "name", "region.y", "tier")),
      "x's columns, then y's non-key columns, with .y on the collision")
check(identical(rownames(j), as.character(1:5)), "default row names")

# --- x's row order survives --------------------------------------------
check(identical(j$cust, c("c3", "c1", "c9", "c1", "c2")),
      "x's row order must be preserved exactly")
check(near(j$amount, c(10, 20, 30, 40, 50)), "x's payload follows its rows")
check(identical(j$region, c("N", "S", "N", "E", "W")),
      "x's own column keeps its name and its values")

# --- y's payload lands on the right rows -------------------------------
check(identical(j$name, c("Carol", "Alice", NA, "Alice", "Bob")),
      "matched values, NA where x's key is absent from y")
check(identical(j$region.y, c("east", "north", NA, "north", "south")),
      "the renamed y column carries y's values")
check(identical(j$tier, c(3L, 1L, NA, 1L, 2L)), "integer payload")
check(is.integer(j$tier), "an unmatched row must not change the column type")

# --- a repeated key in x is fine; it just matches twice ----------------
check(identical(sum(j$name == "Alice", na.rm = TRUE), 2L),
      "a key repeated in x matches on both of its rows")

# --- anti_join_df -------------------------------------------------------
a <- anti_join_df(mkx(), mky(), "cust")
check(is.data.frame(a), "anti_join_df must return a data frame")
check(identical(nrow(a), 1L), "one unmatched row")
check(identical(names(a), c("cust", "amount", "region")),
      "all of x's columns, and only those")
check(identical(a$cust, "c9"), "the unmatched key")
check(near(a$amount, 30), "the unmatched row's payload")
check(identical(rownames(a), "1"), "row names renumbered")

# --- join_coverage ------------------------------------------------------
cov <- join_coverage(mkx(), mky(), "cust")
check(is.list(cov), "join_coverage must return a list")
check(identical(names(cov), c("matched", "unmatched", "unmatched_keys")),
      "coverage element names")
check(identical(cov$matched, 4L), "matched count")
check(identical(cov$unmatched, 1L), "unmatched count")
check(is.integer(cov$matched) && is.integer(cov$unmatched),
      "counts must be integer")
check(identical(cov$unmatched_keys, "c9"), "the distinct unmatched keys")
check(is.character(cov$unmatched_keys), "unmatched_keys must be character")

cat("ok\n")
