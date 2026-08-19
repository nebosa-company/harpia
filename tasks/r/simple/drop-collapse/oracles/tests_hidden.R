source("subset.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

mk <- function() {
  data.frame(
    id = 1:5,
    name = c("a", "b", "c", "d", "e"),
    score = c(10, 20, 30, 40, 50),
    stringsAsFactors = FALSE
  )
}

# --- pick keeps a frame even when one column is left -------------------
p1 <- pick(mk(), "score")
check(is.data.frame(p1), "pick with one column must return a data frame")
check(identical(ncol(p1), 1L), "one column out")
check(identical(nrow(p1), 5L), "all rows kept")
check(identical(names(p1), "score"), "column name kept")
check(near(p1$score, c(10, 20, 30, 40, 50)), "values kept")
check(identical(rownames(p1), as.character(1:5)), "row names 1..n")

p2 <- pick(mk(), c("score", "id"))
check(is.data.frame(p2), "pick with two columns returns a frame")
check(identical(names(p2), c("score", "id")), "columns follow the given order")
check(identical(p2$id, 1:5), "integer column keeps its type")
check(is.integer(p2$id), "integer stays integer")

# --- drop_cols keeps a frame even when one column is left --------------
d1 <- drop_cols(mk(), c("name", "score"))
check(is.data.frame(d1), "drop_cols down to one column must return a frame")
check(identical(names(d1), "id"), "the remaining column")
check(identical(d1$id, 1:5), "values kept")

d2 <- drop_cols(mk(), "name")
check(identical(names(d2), c("id", "score")), "remaining columns keep order")

# --- filter_rows -------------------------------------------------------
f1 <- filter_rows(mk(), mk()$score > 25)
check(is.data.frame(f1), "filter_rows must return a data frame")
check(identical(nrow(f1), 3L), "three rows survive")
check(identical(f1$id, c(3L, 4L, 5L)), "the right rows survive")
check(identical(rownames(f1), c("1", "2", "3")),
      "row names are renumbered after filtering")
check(identical(names(f1), c("id", "name", "score")), "all columns kept")

one <- pick(mk(), "score")
f2 <- filter_rows(one, one$score > 25)
check(is.data.frame(f2), "filtering a one-column frame returns a frame")
check(identical(nrow(f2), 3L), "one-column filter row count")
check(identical(rownames(f2), c("1", "2", "3")), "one-column filter row names")

# --- head_frame --------------------------------------------------------
h1 <- head_frame(mk(), 2)
check(is.data.frame(h1), "head_frame must return a data frame")
check(identical(nrow(h1), 2L), "two rows")
check(identical(h1$id, c(1L, 2L)), "the first rows")
check(identical(rownames(h1), c("1", "2")), "row names 1..n")

h2 <- head_frame(pick(mk(), "name"), 3)
check(is.data.frame(h2), "head of a one-column frame is a frame")
check(identical(h2$name, c("a", "b", "c")), "one-column head values")

cat("ok\n")
