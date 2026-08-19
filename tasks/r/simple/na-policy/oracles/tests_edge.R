source("clean.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

mk <- function() {
  data.frame(
    id    = 1:6,
    score = c(10, NA, 30, NA, 50, 60),
    grade = c("a", "b", NA, "d", "e", NA),
    n     = c(1L, 2L, NA, 4L, 5L, 6L),
    stringsAsFactors = FALSE
  )
}

# --- median ------------------------------------------------------------
med <- clean_frame(mk(), list(score = "median"))
check(near(med$score, c(10, 40, 30, 40, 50, 60)), "median fill")

# --- two drops compose --------------------------------------------------
both <- clean_frame(mk(), list(score = "drop", grade = "drop"))
check(identical(both$id, c(1L, 5L)), "both drop rules applied")
check(identical(nrow(both), 2L), "two rows survive")
check(identical(rownames(both), c("1", "2")), "row names renumbered")

# --- an empty policy still renumbers ------------------------------------
d <- mk()
rownames(d) <- c("r1", "r2", "r3", "r4", "r5", "r6")
untouched <- clean_frame(d)
check(identical(rownames(untouched), as.character(1:6)),
      "an empty policy renumbers the row names")
check(identical(untouched$score, d$score), "an empty policy changes no data")
check(identical(untouched$grade, d$grade), "character column untouched")

# --- errors --------------------------------------------------------------
check(identical(msg(clean_frame(mk(), list(nope = "drop"))),
                "no such column: nope"), "unknown column rejected")
check(identical(msg(clean_frame(mk(), list(grade = "mean"))),
                "column grade is not numeric"),
      "mean on a character column rejected")
check(identical(msg(clean_frame(mk(), list(grade = "median"))),
                "column grade is not numeric"),
      "median on a character column rejected")
check(identical(msg(clean_frame(mk(), list(score = "wat"))),
                "unknown policy for column score"),
      "unrecognised keyword rejected")
check(identical(msg(clean_frame(mk(), list(score = 5))),
                "unknown policy for column score"),
      "a bare value is not a policy")

# --- empty frames --------------------------------------------------------
e <- data.frame(a = numeric(0), b = character(0), stringsAsFactors = FALSE)
re <- na_report(e)
check(identical(nrow(re), 2L), "na_report has one row per column")
check(identical(re$n_missing, c(0L, 0L)), "no missing values in an empty frame")
check(identical(re$pct_missing, c(0, 0)),
      "an empty frame reports a share of exactly 0, never NaN")
check(identical(complete_rows(e), logical(0)),
      "complete_rows on an empty frame is logical(0)")

ce <- clean_frame(e, list(a = "mean"))
check(identical(nrow(ce), 0L), "cleaning an empty frame keeps it empty")
check(identical(names(ce), c("a", "b")), "columns survive an empty frame")

# --- a fully missing column -------------------------------------------
allna <- data.frame(x = c(NA, NA), y = c(1, 2))
check(identical(complete_rows(allna), c(FALSE, FALSE)), "no complete rows")
check(near(na_report(allna)$pct_missing, c(1, 0)), "a fully missing column")

cat("ok\n")
