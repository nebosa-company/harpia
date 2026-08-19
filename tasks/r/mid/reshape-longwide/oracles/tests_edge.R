source("pivot.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

wide <- data.frame(id = c("a", "b"), q1 = c(1, 3), q2 = c(2, 4),
                   stringsAsFactors = FALSE)

# --- missing columns are reported --------------------------------------
check(identical(msg(to_long(wide, "nope", "q1")), "no such column: nope"),
      "to_long checks its id columns")
check(identical(msg(to_long(wide, "id", "zzz")), "no such column: zzz"),
      "to_long checks its value columns")
check(identical(msg(to_long(wide, "id", character(0))),
                "value_cols must not be empty"),
      "an empty value_cols is refused")
check(identical(msg(to_wide(wide, "id", "nope", "q1")),
                "no such column: nope"), "to_wide checks name_from")
check(identical(msg(transpose_frame(wide, "nope")), "no such column: nope"),
      "transpose_frame checks its id column")

# --- a duplicated cell cannot be widened -------------------------------
dup <- data.frame(id = c("a", "a"), k = c("p", "p"), v = c(1, 2),
                  stringsAsFactors = FALSE)
check(identical(msg(to_wide(dup, "id", "k", "v")),
                "duplicate cell in column p"),
      "two values for the same cell must be an error")

dup2 <- data.frame(id = c("a", "b", "a"), k = c("p", "q", "q"),
                   v = c(1, 2, 3), stringsAsFactors = FALSE)
check(is.na(msg(to_wide(dup2, "id", "k", "v"))),
      "distinct cells with a repeated id are fine")
w2 <- to_wide(dup2, "id", "k", "v")
check(identical(names(w2), c("id", "p", "q")), "columns by first appearance")
check(identical(w2$id, c("a", "b")), "ids by first appearance")
check(near(w2$p[1], 1) && is.na(w2$p[2]), "sparse first column")
check(near(w2$q, c(3, 2)), "the second column lands on the right rows")

# --- id combinations keep the order of first appearance ---------------
ord <- data.frame(id = c("z", "a", "z", "a"), k = c("p", "p", "q", "q"),
                  v = c(1, 2, 3, 4), stringsAsFactors = FALSE)
wo <- to_wide(ord, "id", "k", "v")
check(identical(wo$id, c("z", "a")), "first appearance, not sorted")
check(near(wo$p, c(1, 2)), "p column")
check(near(wo$q, c(3, 4)), "q column")

# --- id column types survive the round trip ---------------------------
typed <- data.frame(yr = c(2023L, 2024L), a = c(1.5, 2.5), b = c(3.5, 4.5))
lt <- to_long(typed, "yr", c("a", "b"))
check(is.integer(lt$yr), "an integer id column stays integer in long form")
check(identical(lt$yr, c(2023L, 2023L, 2024L, 2024L)), "ids repeat per value")
bt <- to_wide(lt, "yr", "name", "value")
check(is.integer(bt$yr), "an integer id column survives the round trip")
check(identical(bt, typed), "the round trip is exact for typed frames")

# --- mixed value column types promote as c() would --------------------
mixed <- data.frame(id = "a", num = 1L, txt = "hello",
                    stringsAsFactors = FALSE)
lm <- to_long(mixed, "id", c("num", "txt"))
check(is.character(lm$value), "mixing integer and character gives character")
check(identical(lm$value, c("1", "hello")), "promoted values")

# --- a single row and a single value column ---------------------------
one <- to_long(wide[1, , drop = FALSE], "id", "q1")
check(identical(nrow(one), 1L), "one row, one value column")
check(identical(one$name, "q1"), "the single name")
check(near(one$value, 1), "the single value")

# --- an empty frame ------------------------------------------------------
empty <- wide[0, , drop = FALSE]
le <- to_long(empty, "id", c("q1", "q2"))
check(identical(nrow(le), 0L), "no rows in, no rows out")
check(identical(names(le), c("id", "name", "value")), "columns still there")
check(is.character(le$name), "the name column keeps its type")
check(is.double(le$value), "the value column keeps its type")

# --- transpose_frame refuses ambiguous labels -------------------------
dupl <- data.frame(k = c("a", "a"), v = c(1, 2), stringsAsFactors = FALSE)
check(identical(msg(transpose_frame(dupl, "k")), "duplicate row labels"),
      "repeated labels would give duplicate column names")

mixt <- data.frame(k = c("r1", "r2"), n = c(1L, 2L), s = c("x", "y"),
                   stringsAsFactors = FALSE)
tm <- transpose_frame(mixt, "k")
check(identical(names(tm), c("name", "r1", "r2")), "transposed column names")
check(identical(tm$name, c("n", "s")), "original column names become rows")
check(identical(tm$r1, c("1", "x")), "mixed types all become character")
check(identical(tm$r2, c("2", "y")), "second transposed column")

cat("ok\n")
