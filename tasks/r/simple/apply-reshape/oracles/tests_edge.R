source("applyx.R")
.defined <- ls(envir = globalenv())

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-8))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

# --- no explicit loops anywhere in the file ----------------------------
graded <- Filter(
  function(n) is.function(get(n, envir = globalenv())),
  .defined
)
check(all(c("col_summary", "matrix_to_long", "group_apply") %in% graded),
      "the three helpers must be defined in applyx.R")
loopy <- Filter(
  function(n) {
    tryCatch({
      txt <- paste(deparse(body(get(n, envir = globalenv()))), collapse = "\n")
      grepl("(^|[^[:alnum:]._])(for|while|repeat)([^[:alnum:]._]|$)", txt)
    }, error = function(e) FALSE)
  },
  graded
)
check(length(loopy) == 0L,
      paste("explicit loop found in:", paste(loopy, collapse = ", ")))

# --- col_summary corner cases ------------------------------------------
one <- data.frame(v = c(7, NA, NA))
cs1 <- col_summary(one)
check(identical(cs1$n, 1L), "a single non-NA value counts as one")
check(near(cs1$mean, 7), "mean of a single value")
check(is.na(cs1$sd), "sd of a single value is NA")
check(near(cs1$min, 7) && near(cs1$max, 7), "min and max of a single value")

nonum <- data.frame(a = c("p", "q"), b = c(TRUE, FALSE),
                    stringsAsFactors = FALSE)
cs0 <- col_summary(nonum)
check(identical(nrow(cs0), 0L), "no numeric columns gives no rows")
check(identical(names(cs0), c("column", "n", "mean", "sd", "min", "max")),
      "the empty result keeps its columns")
check(is.character(cs0$column), "empty result: column stays character")
check(is.integer(cs0$n), "empty result: n stays integer")
check(is.double(cs0$mean), "empty result: mean stays double")

# --- matrix_to_long rejects what it cannot label ------------------------
check(identical(msg(matrix_to_long(1:6)), "expected a matrix"),
      "a bare vector is not a matrix")
check(identical(msg(matrix_to_long(matrix(1:4, 2))),
                "matrix needs row and column names"),
      "an unnamed matrix is refused")
check(identical(msg(matrix_to_long(matrix(1:4, 2,
                                          dimnames = list(c("a", "b"), NULL)))),
                "matrix needs row and column names"),
      "missing column names are refused")

ch <- matrix(c("a", "b", "c", "d"), nrow = 2,
             dimnames = list(c("r1", "r2"), c("c1", "c2")))
lch <- matrix_to_long(ch)
check(identical(lch$value, c("a", "b", "c", "d")),
      "a character matrix keeps its type")
check(is.character(lch$value), "character element type is preserved")

single <- matrix(5, nrow = 1, dimnames = list("only", "col"))
lsg <- matrix_to_long(single)
check(identical(nrow(lsg), 1L), "a 1x1 matrix gives one row")
check(identical(lsg$row, "only") && identical(lsg$col, "col"),
      "1x1 labels")

# --- group_apply corner cases ------------------------------------------
gna <- data.frame(k = c("a", NA, "a", "b"), v = c(1, 99, 2, 4),
                  stringsAsFactors = FALSE)
gr <- group_apply(gna, "k", "v", sum)
check(identical(gr$k, c("a", "b")), "an NA key forms no group")
check(near(gr$value, c(3, 4)), "NA-keyed rows are excluded from every group")

empty <- data.frame(k = character(0), v = numeric(0),
                    stringsAsFactors = FALSE)
ge <- group_apply(empty, "k", "v", sum)
check(identical(nrow(ge), 0L), "no rows in, no rows out")
check(identical(names(ge), c("k", "value")), "empty result keeps its columns")

# --- keys are compared as character, so "10" sorts before "9" ----------
gnum <- data.frame(k = c(10, 9, 10, 2), v = c(1, 2, 3, 4))
gn <- group_apply(gnum, "k", "v", sum)
check(identical(gn$k, c("10", "2", "9")), "numeric keys sort as character")
check(near(gn$value, c(4, 4, 2)), "sums follow the character ordering")

cat("ok\n")
