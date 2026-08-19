source("subset.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)

mk <- function() {
  data.frame(
    id = 1:5,
    name = c("a", "b", "c", "d", "e"),
    score = c(10, 20, 30, 40, 50),
    stringsAsFactors = FALSE
  )
}

# --- NA in the filter counts as FALSE, it does not make a row ----------
f <- filter_rows(mk(), c(TRUE, NA, TRUE, FALSE, NA))
check(identical(nrow(f), 2L), "NA must not select a row")
check(identical(f$id, c(1L, 3L)), "only the TRUE rows survive")
check(!any(is.na(f$name)), "no phantom all-NA row")
check(identical(rownames(f), c("1", "2")), "row names renumbered")

# --- an empty result is still a frame ----------------------------------
e <- filter_rows(mk(), rep(FALSE, 5))
check(is.data.frame(e), "an empty filter result is still a data frame")
check(identical(nrow(e), 0L), "no rows")
check(identical(names(e), c("id", "name", "score")), "all columns kept")
check(is.integer(e$id), "column types survive an empty result")

e1 <- filter_rows(pick(mk(), "score"), rep(FALSE, 5))
check(is.data.frame(e1), "empty one-column result is a data frame")
check(identical(nrow(e1), 0L), "no rows")
check(identical(names(e1), "score"), "the single column survives")

# --- head_frame boundaries ---------------------------------------------
h0 <- head_frame(mk(), 0)
check(is.data.frame(h0), "head_frame(df, 0) is a data frame")
check(identical(nrow(h0), 0L), "zero rows requested, zero returned")
check(identical(names(h0), c("id", "name", "score")), "columns kept")

hneg <- head_frame(mk(), -3)
check(is.data.frame(hneg), "a negative count is a data frame")
check(identical(nrow(hneg), 0L), "a negative count yields no rows")

hbig <- head_frame(mk(), 99)
check(identical(nrow(hbig), 5L), "asking for more rows than exist")
check(identical(hbig$id, 1:5), "all rows returned")

hone <- head_frame(pick(mk(), "id"), 1)
check(is.data.frame(hone), "one row of one column is still a frame")
check(identical(nrow(hone), 1L), "exactly one row")
check(identical(hone$id, 1L), "the first value")

# --- row names are rebuilt, never inherited ---------------------------
odd <- mk()
rownames(odd) <- c("r1", "r2", "r3", "r4", "r5")
check(identical(rownames(pick(odd, "score")), as.character(1:5)),
      "pick renumbers inherited row names")
check(identical(rownames(drop_cols(odd, "name")), as.character(1:5)),
      "drop_cols renumbers inherited row names")
check(identical(rownames(head_frame(odd, 2)), c("1", "2")),
      "head_frame renumbers inherited row names")
check(identical(rownames(filter_rows(odd, c(FALSE, TRUE, FALSE, TRUE, TRUE))),
                c("1", "2", "3")),
      "filter_rows renumbers inherited row names")

# --- chained calls keep returning frames -------------------------------
chained <- head_frame(filter_rows(pick(mk(), "score"), mk()$score > 15), 2)
check(is.data.frame(chained), "chained calls stay data frames")
check(identical(nrow(chained), 2L), "chained row count")
check(identical(names(chained), "score"), "chained column")

cat("ok\n")
