source("clean.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

mk <- function() {
  data.frame(
    id    = 1:6,
    score = c(10, NA, 30, NA, 50, 60),
    grade = c("a", "b", NA, "d", "e", NA),
    n     = c(1L, 2L, NA, 4L, 5L, 6L),
    stringsAsFactors = FALSE
  )
}

# --- na_report ---------------------------------------------------------
rep1 <- na_report(mk())
check(is.data.frame(rep1), "na_report must return a data frame")
check(identical(names(rep1), c("column", "n_missing", "pct_missing")),
      "na_report column names")
check(identical(rep1$column, c("id", "score", "grade", "n")),
      "one row per column, in column order")
check(is.integer(rep1$n_missing), "n_missing must be integer")
check(identical(rep1$n_missing, c(0L, 2L, 2L, 1L)), "missing counts")
check(is.double(rep1$pct_missing), "pct_missing must be double")
check(near(rep1$pct_missing, c(0, 1 / 3, 1 / 3, 1 / 6)), "missing shares")
check(identical(rownames(rep1), as.character(1:4)), "default row names")

# --- complete_rows -----------------------------------------------------
cr <- complete_rows(mk())
check(is.logical(cr), "complete_rows must return a logical vector")
check(identical(cr, c(TRUE, FALSE, FALSE, FALSE, TRUE, FALSE)),
      "complete rows")

# --- fills only --------------------------------------------------------
out <- clean_frame(mk(), list(score = "mean", grade = list(fill = "unknown")))
check(identical(names(out), c("id", "score", "grade", "n")),
      "columns keep their order")
check(identical(nrow(out), 6L), "no rows dropped")
check(near(out$score, c(10, 37.5, 30, 37.5, 50, 60)), "mean fill")
check(identical(out$grade, c("a", "b", "unknown", "d", "e", "unknown")),
      "literal fill")
check(identical(out$n, c(1L, 2L, NA_integer_, 4L, 5L, 6L)),
      "columns with no policy are untouched")
check(identical(rownames(out), as.character(1:6)), "row names renumbered")

# --- drop then fill: the statistic is taken after the drop -------------
out2 <- clean_frame(mk(), list(grade = "drop", score = "mean"))
check(identical(nrow(out2), 4L), "rows with a missing grade are gone")
check(identical(out2$id, c(1L, 2L, 4L, 5L)), "surviving rows")
check(near(out2$score, c(10, 30, 30, 50)),
      "the mean must be computed on the surviving rows (30, not 37.5)")
check(identical(out2$grade, c("a", "b", "d", "e")), "grades survive intact")
check(identical(rownames(out2), as.character(1:4)), "row names renumbered")

# --- the order the policy list is written in must not matter -----------
out3 <- clean_frame(mk(), list(score = "mean", grade = "drop"))
check(identical(out3, out2), "policy list order is irrelevant")

# --- drop plus a literal fill ------------------------------------------
out4 <- clean_frame(mk(), list(score = "drop", n = list(fill = 0L)))
check(identical(out4$id, c(1L, 3L, 5L, 6L)), "rows kept after dropping")
check(near(out4$score, c(10, 30, 50, 60)), "score column after the drop")
check(identical(out4$n, c(1L, 0L, 5L, 6L)), "integer fill")
check(is.integer(out4$n), "an integer fill keeps the column integer")

cat("ok\n")
