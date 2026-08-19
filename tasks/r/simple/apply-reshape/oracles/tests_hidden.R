source("applyx.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-8))

df <- data.frame(
  a = c(1, 2, 3, 4),
  b = c("x", "y", "x", "z"),
  c = c(10L, NA, 30L, 40L),
  d = c(NA_real_, NA_real_, NA_real_, NA_real_),
  stringsAsFactors = FALSE
)

# --- col_summary -------------------------------------------------------
cs <- col_summary(df)
check(is.data.frame(cs), "col_summary must return a data frame")
check(identical(names(cs), c("column", "n", "mean", "sd", "min", "max")),
      "col_summary column names")
check(identical(cs$column, c("a", "c", "d")),
      "numeric columns only, in column order")
check(is.character(cs$column), "column must be character")
check(is.integer(cs$n), "n must be integer")
check(identical(cs$n, c(4L, 3L, 0L)), "non-NA counts")
check(is.double(cs$mean) && is.double(cs$sd), "mean and sd must be double")
check(is.double(cs$min) && is.double(cs$max), "min and max must be double")
check(near(cs$mean[1:2], c(2.5, 80 / 3)), "means over non-NA values")
check(near(cs$sd[1:2], c(sd(c(1, 2, 3, 4)), sd(c(10, 30, 40)))), "sds")
check(near(cs$min[1:2], c(1, 10)), "minima")
check(near(cs$max[1:2], c(4, 40)), "maxima")
check(is.na(cs$mean[3]) && is.na(cs$sd[3]), "all-NA column: mean and sd")
check(is.na(cs$min[3]) && is.na(cs$max[3]),
      "an all-NA column must give NA, never Inf")
check(identical(rownames(cs), c("1", "2", "3")), "default row names")

# --- matrix_to_long ----------------------------------------------------
m <- matrix(1:6, nrow = 2,
            dimnames = list(c("r1", "r2"), c("c1", "c2", "c3")))
long <- matrix_to_long(m)
check(is.data.frame(long), "matrix_to_long must return a data frame")
check(identical(names(long), c("row", "col", "value")), "long column names")
check(identical(nrow(long), 6L), "one row per cell")
check(identical(long$row, c("r1", "r2", "r1", "r2", "r1", "r2")),
      "column-major row labels")
check(identical(long$col, c("c1", "c1", "c2", "c2", "c3", "c3")),
      "column-major column labels")
check(identical(long$value, 1:6), "values in column-major order")
check(is.integer(long$value), "the matrix element type is preserved")
check(identical(rownames(long), as.character(1:6)), "default row names")

# --- group_apply -------------------------------------------------------
g <- data.frame(k = c("b", "a", "b", "c", "a"),
                v = c(1, 10, 3, 5, 20),
                stringsAsFactors = FALSE)
ga <- group_apply(g, "k", "v", sum)
check(is.data.frame(ga), "group_apply must return a data frame")
check(identical(names(ga), c("k", "value")),
      "the first column is named after `by`")
check(is.character(ga[[1]]), "group labels are character")
check(identical(ga$k, c("a", "b", "c")), "groups sorted ascending")
check(is.double(ga$value), "value must be double")
check(near(ga$value, c(30, 4, 5)), "grouped sums")
check(identical(rownames(ga), c("1", "2", "3")), "default row names")

gm <- group_apply(g, "k", "v", mean)
check(near(gm$value, c(15, 2, 5)), "grouped means")
gl <- group_apply(g, "k", "v", length)
check(near(gl$value, c(2, 2, 1)), "grouped counts")
check(is.double(gl$value), "counts are returned as double")

cat("ok\n")
