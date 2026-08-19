source("pivot.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

wide <- data.frame(
  id = c("a", "b"),
  g = c("x", "y"),
  q1 = c(1, 3),
  q2 = c(2, 4),
  stringsAsFactors = FALSE
)

# --- to_long ------------------------------------------------------------
lg <- to_long(wide, c("id", "g"), c("q1", "q2"))
check(is.data.frame(lg), "to_long must return a data frame")
check(identical(names(lg), c("id", "g", "name", "value")),
      "id columns, then name, then value")
check(identical(nrow(lg), 4L), "rows times value columns")
check(identical(lg$id, c("a", "a", "b", "b")), "row-major id ordering")
check(identical(lg$g, c("x", "x", "y", "y")), "the second id column follows")
check(identical(lg$name, c("q1", "q2", "q1", "q2")),
      "each source row contributes its value columns in order")
check(is.character(lg$name), "the name column is character")
check(near(lg$value, c(1, 2, 3, 4)), "values in row-major order")
check(identical(rownames(lg), as.character(1:4)), "default row names")

# --- the order of value_cols drives the output order -------------------
lg2 <- to_long(wide, "id", c("q2", "q1"))
check(identical(lg2$name, c("q2", "q1", "q2", "q1")),
      "value_cols order is honoured")
check(near(lg2$value, c(2, 1, 4, 3)), "values follow the requested order")
check(identical(names(lg2), c("id", "name", "value")), "one id column")

# --- custom output names ------------------------------------------------
lg3 <- to_long(wide, "id", c("q1", "q2"), name_to = "quarter",
               value_to = "amount")
check(identical(names(lg3), c("id", "quarter", "amount")),
      "name_to and value_to rename the output columns")
check(identical(lg3$quarter, c("q1", "q2", "q1", "q2")), "renamed name column")

# --- to_wide, and the round trip ---------------------------------------
back <- to_wide(lg, c("id", "g"), "name", "value")
check(is.data.frame(back), "to_wide must return a data frame")
check(identical(names(back), c("id", "g", "q1", "q2")),
      "id columns then one column per name")
check(identical(nrow(back), 2L), "one row per id combination")
check(identical(back$id, c("a", "b")), "id order of first appearance")
check(near(back$q1, c(1, 3)), "first value column")
check(near(back$q2, c(2, 4)), "second value column")
check(identical(rownames(back), c("1", "2")), "default row names")
check(identical(back, wide), "widening a long frame reproduces the original")

# --- missing cells take the fill ---------------------------------------
sparse <- data.frame(id = c("a", "a", "b"), k = c("p", "q", "p"),
                     v = c(1, 2, 3), stringsAsFactors = FALSE)
w1 <- to_wide(sparse, "id", "k", "v")
check(identical(names(w1), c("id", "p", "q")),
      "columns in order of first appearance")
check(near(w1$p, c(1, 3)), "the fully populated column")
check(is.na(w1$q[2]), "a missing cell defaults to NA")
check(near(w1$q[1], 2), "the populated cell of a sparse column")

w2 <- to_wide(sparse, "id", "k", "v", fill = 0)
check(near(w2$q, c(2, 0)), "an explicit fill is used")
check(is.double(w2$q), "the filled column is numeric")

# --- transpose_frame ----------------------------------------------------
tf <- data.frame(metric = c("rev", "cost"), q1 = c(10, 4), q2 = c(20, 5),
                 stringsAsFactors = FALSE)
tr <- transpose_frame(tf, "metric")
check(is.data.frame(tr), "transpose_frame must return a data frame")
check(identical(names(tr), c("name", "rev", "cost")),
      "name column, then one column per row")
check(identical(tr$name, c("q1", "q2")), "the other column names become rows")
check(identical(tr$rev, c("10", "20")), "values converted to character")
check(identical(tr$cost, c("4", "5")), "second row's values")
check(is.character(tr$rev), "every cell is character")
check(identical(rownames(tr), c("1", "2")), "default row names")

cat("ok\n")
