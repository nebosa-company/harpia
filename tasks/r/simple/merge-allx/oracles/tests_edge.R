source("joins.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

mkx <- function() {
  data.frame(cust = c("c3", "c1", "c9"), amount = c(10, 20, 30),
             stringsAsFactors = FALSE)
}
mky <- function() {
  data.frame(cust = c("c1", "c2", "c3"), name = c("Alice", "Bob", "Carol"),
             stringsAsFactors = FALSE)
}

# --- a repeated key in y is refused, not silently expanded -------------
ydup <- data.frame(cust = c("c1", "c3", "c1"), name = c("A", "B", "C"),
                   stringsAsFactors = FALSE)
check(identical(msg(left_join_df(mkx(), ydup, "cust")),
                "duplicate keys in y: c1"),
      "a duplicated right-hand key must be an error")

ydup2 <- data.frame(cust = c("c3", "c9", "c9", "c3"), name = LETTERS[1:4],
                    stringsAsFactors = FALSE)
check(identical(msg(left_join_df(mkx(), ydup2, "cust")),
                "duplicate keys in y: c9"),
      "the first key that repeats in y's row order is named")

# --- a missing key column ----------------------------------------------
nokey <- data.frame(other = c("c1"), name = "A", stringsAsFactors = FALSE)
check(identical(msg(left_join_df(nokey, mky(), "cust")),
                "no key column cust in x"), "missing key in x")
check(identical(msg(left_join_df(mkx(), nokey, "cust")),
                "no key column cust in y"), "missing key in y")
check(identical(msg(left_join_df(nokey, nokey, "cust")),
                "no key column cust in x"), "x is checked first")

# --- NA keys never match, on either side -------------------------------
xn <- data.frame(cust = c("c1", NA, "c2"), v = 1:3, stringsAsFactors = FALSE)
yn <- data.frame(cust = c("c1", NA), lab = c("A", "B"),
                 stringsAsFactors = FALSE)
jn <- left_join_df(xn, yn, "cust")
check(identical(nrow(jn), 3L), "row count unchanged by NA keys")
check(identical(jn$lab, c("A", NA, NA)),
      "an NA key on the left must not match an NA key on the right")

covn <- join_coverage(xn, yn, "cust")
check(identical(covn$matched, 1L), "only the real key matched")
check(identical(covn$unmatched, 2L), "NA counts as unmatched")
check(identical(covn$unmatched_keys, c(NA_character_, "c2")),
      "unmatched keys, distinct, in x's order")

an <- anti_join_df(xn, yn, "cust")
check(identical(nrow(an), 2L), "the NA-keyed row is unmatched")
check(identical(an$v, c(2L, 3L)), "the right rows are unmatched")

# --- repeated NA keys in y are not "duplicates" -------------------------
ynn <- data.frame(cust = c("c1", NA, NA), lab = c("A", "B", "C"),
                  stringsAsFactors = FALSE)
check(is.na(msg(left_join_df(xn, ynn, "cust"))),
      "repeated NA keys in y must not trip the duplicate check")

# --- keys are compared as labels, not as factor codes ------------------
xf <- data.frame(cust = factor(c("c2", "c1")), v = 1:2)
yf <- data.frame(cust = c("c1", "c2"), lab = c("A", "B"),
                 stringsAsFactors = FALSE)
jf <- left_join_df(xf, yf, "cust")
check(identical(jf$lab, c("B", "A")),
      "a factor key joins on its labels, not on its integer codes")

# --- empty frames --------------------------------------------------------
xe <- mkx()[0, , drop = FALSE]
je <- left_join_df(xe, mky(), "cust")
check(is.data.frame(je), "an empty left frame still gives a data frame")
check(identical(nrow(je), 0L), "no rows in, no rows out")
check(identical(names(je), c("cust", "amount", "name")),
      "the empty result still carries y's columns")
check(is.character(je$name), "y's column type survives an empty join")

ye <- mky()[0, , drop = FALSE]
j0 <- left_join_df(mkx(), ye, "cust")
check(identical(nrow(j0), 3L), "an empty right frame keeps every left row")
check(all(is.na(j0$name)), "nothing matches an empty right frame")
check(identical(nrow(anti_join_df(mkx(), ye, "cust")), 3L),
      "everything is unmatched against an empty right frame")

cov0 <- join_coverage(mkx(), ye, "cust")
check(identical(cov0$matched, 0L), "no matches at all")
check(identical(cov0$unmatched_keys, c("c3", "c1", "c9")),
      "every key is unmatched, in x's order")

cat("ok\n")
