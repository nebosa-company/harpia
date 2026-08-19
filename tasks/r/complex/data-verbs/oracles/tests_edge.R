source("verbs.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

mk <- function() {
  data.frame(
    g = c("b", "a", "b", "c", "a", "b"),
    n = c(3L, 1L, 5L, 2L, 4L, 6L),
    v = c(10, 20, 30, 40, 50, 60),
    stringsAsFactors = FALSE
  )
}

# --- error messages -----------------------------------------------------
check(identical(msg(select_cols(mk(), nope)), "no such column: nope"),
      "select_cols reports an unknown column")
check(identical(msg(select_cols(mk(), g, -n)),
                "cannot mix kept and dropped columns"),
      "keeps and drops cannot be mixed")
check(identical(msg(select_cols(mk())),
                "select_cols needs at least one column"),
      "select_cols needs an argument")
check(identical(msg(arrange_rows(mk())),
                "arrange_rows needs at least one column"),
      "arrange_rows needs an argument")
check(identical(msg(arrange_rows(mk(), zzz)), "no such column: zzz"),
      "arrange_rows reports an unknown column")
check(identical(msg(arrange_rows(mk(), desc(zzz))), "no such column: zzz"),
      "and reports it through desc too")
check(identical(msg(mutate_cols(mk(), v * 2)),
                "every mutation must be named"),
      "an unnamed mutation is refused")
check(identical(msg(mutate_cols(mk(), bad = c(1, 2))),
                "column bad has the wrong length"),
      "a wrong-length mutation is refused")
check(identical(msg(filter_rows(mk(), c(TRUE, FALSE))),
                "condition must give one value per row"),
      "a wrong-length condition is refused")
check(identical(msg(summarise_groups(mk(), "g")),
                "summarise_groups needs at least one summary"),
      "summarise_groups needs a summary")
check(identical(msg(summarise_groups(mk(), "g", sum(v))),
                "every summary must be named"),
      "an unnamed summary is refused")
check(identical(msg(summarise_groups(mk(), "zzz", t = sum(v))),
                "no such column: zzz"),
      "summarise_groups checks its keys")

# --- NA in a filter condition counts as FALSE --------------------------
withna <- mk()
withna$v[c(2, 5)] <- NA
fn <- filter_rows(withna, v > 25)
check(identical(fn$n, c(5L, 2L, 6L)), "NA rows are dropped, not kept as NA")
check(!any(is.na(fn$v)), "no phantom NA rows")

# --- an empty result keeps its shape -----------------------------------
none <- filter_rows(mk(), v > 1000)
check(is.data.frame(none), "an empty filter result is a data frame")
check(identical(nrow(none), 0L), "no rows")
check(identical(names(none), c("g", "n", "v")), "all columns survive")
check(is.integer(none$n), "column types survive")

check(identical(nrow(select_cols(none, v)), 0L),
      "selecting from an empty frame")
check(identical(nrow(arrange_rows(none, v)), 0L),
      "arranging an empty frame")
me <- mutate_cols(none, w = v * 2)
check(identical(nrow(me), 0L), "mutating an empty frame")
check(identical(names(me), c("g", "n", "v", "w")), "the new column exists")

sge <- summarise_groups(none, "g", total = sum(v))
check(identical(nrow(sge), 0L), "summarising an empty frame")
check(identical(names(sge), c("g", "total")), "its columns still exist")
check(is.character(sge$g), "the key column keeps its type")
check(is.double(sge$total), "the summary column keeps its type")

# --- arrange: mixed directions, NA last, character keys ----------------
mixed <- arrange_rows(mk(), g, desc(n))
check(identical(mixed$g, c("a", "a", "b", "b", "b", "c")), "primary ascending")
check(identical(mixed$n, c(4L, 1L, 6L, 5L, 3L, 2L)), "secondary descending")

nas <- mk()
nas$v[2] <- NA
an <- arrange_rows(nas, v)
check(is.na(an$v[6]), "NA sorts last when ascending")
check(near(an$v[1], 10), "the smallest real value comes first")
ad <- arrange_rows(nas, desc(v))
check(is.na(ad$v[6]), "NA sorts last when descending too")
check(near(ad$v[1], 60), "the largest real value comes first")

ac <- arrange_rows(mk(), desc(g))
check(identical(ac$g, c("c", "b", "b", "b", "a", "a")),
      "a character key sorts downwards")
check(identical(ac$n, c(2L, 3L, 5L, 6L, 1L, 4L)),
      "and stays stable within each tie")

# --- mutate sees the caller's environment ------------------------------
factor_v <- 3
mm <- mutate_cols(mk(), scaled = v * factor_v)
check(near(mm$scaled, c(30, 60, 90, 120, 150, 180)),
      "a local variable resolves inside a mutation")

# --- a column shadows a same-named variable ---------------------------
v <- 999
fs <- filter_rows(mk(), v > 25)
check(identical(nrow(fs), 4L),
      "the data frame's column wins over a variable of the same name")

# --- summarise drops NA-keyed rows -------------------------------------
kna <- mk()
kna$g[c(2, 4)] <- NA
sk <- summarise_groups(kna, "g", total = sum(v))
check(identical(sk$g, c("a", "b")), "no NA group is created")
check(near(sk$total, c(50, 100)), "NA-keyed rows leave every total")

# --- summarise keeps the key column's type ----------------------------
typed <- data.frame(yr = c(2024L, 2023L, 2024L), v = c(1, 2, 3))
st <- summarise_groups(typed, "yr", total = sum(v))
check(is.integer(st$yr), "an integer key column stays integer")
check(identical(st$yr, c(2023L, 2024L)), "keys sorted as character")
check(near(st$total, c(2, 4)), "the totals")

# --- summarise expressions can use several columns ---------------------
sw <- summarise_groups(mk(), "g", weighted = sum(v * n) / sum(n))
check(near(sw$weighted, c((20 * 1 + 50 * 4) / 5,
                          (10 * 3 + 30 * 5 + 60 * 6) / 14,
                          40)),
      "an expression over two columns, per group")

# --- a longer chain -----------------------------------------------------
chain <- mk() |>
  mutate_cols(score = v / n) |>
  filter_rows(score > 5) |>
  arrange_rows(desc(score)) |>
  select_cols(g, score)
check(identical(names(chain), c("g", "score")), "the chained selection")
check(identical(nrow(chain), 5L), "five rows survive the chain")
check(near(chain$score, c(20, 20, 12.5, 10, 6)),
      "scores in descending order")
check(identical(chain$g, c("a", "c", "a", "b", "b")),
      "labels follow their rows, ties staying stable")

cat("ok\n")
