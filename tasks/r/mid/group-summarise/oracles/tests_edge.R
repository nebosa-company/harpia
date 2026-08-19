source("groupby.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

mk <- function() {
  data.frame(
    region = c("north", "south", "north", "east", "south", "north"),
    year   = c(2023L, 2023L, 2024L, 2023L, 2024L, 2024L),
    sales  = c(10, 20, 30, 40, 50, 60),
    stringsAsFactors = FALSE
  )
}

# --- rows with a missing key belong to no group ------------------------
withna <- mk()
withna$region[c(2, 4)] <- NA
s <- summarise_by(withna, "region", list(total = list(col = "sales", fn = sum)))
check(identical(s$region, c("north", "south")), "no NA group is created")
check(near(s$total, c(100, 50)), "NA-keyed rows leave every total")
check(identical(count_by(withna, "region")$n, c(3L, 1L)),
      "NA-keyed rows are not counted")

gs <- add_group_share(withna, "region", "sales")
check(identical(nrow(gs), 6L), "add_group_share keeps every row")
check(is.na(gs$share[2]) && is.na(gs$share[4]),
      "a row that belongs to no group has an NA share")
check(near(gs$share[c(1, 3, 6)], c(10 / 100, 30 / 100, 60 / 100)),
      "the remaining shares are unaffected")

# --- NA in the value column ---------------------------------------------
nav <- mk()
nav$sales[1] <- NA
gn <- add_group_share(nav, "region", "sales")
check(is.na(gn$share[1]), "an NA value has an NA share")
check(near(gn$share[c(3, 6)], c(30 / 90, 60 / 90)),
      "an NA value is left out of its group's total")

# --- a group total of zero -------------------------------------------
zero <- data.frame(k = c("a", "a", "b"), v = c(5, -5, 2),
                   stringsAsFactors = FALSE)
gz <- add_group_share(zero, "k", "v")
check(is.na(gz$share[1]) && is.na(gz$share[2]),
      "a zero group total gives NA, never Inf")
check(near(gz$share[3], 1), "other groups are unaffected")
check(!any(is.infinite(gz$share)), "no infinities anywhere")

# --- missing columns are reported --------------------------------------
check(identical(msg(summarise_by(mk(), "nope",
                                 list(t = list(col = "sales", fn = sum)))),
                "no such column: nope"), "a missing key column")
check(identical(msg(summarise_by(mk(), "region",
                                 list(t = list(col = "nope", fn = sum)))),
                "no such column: nope"), "a missing spec column")
check(identical(msg(count_by(mk(), c("region", "nope"))),
                "no such column: nope"), "count_by checks its keys")
check(identical(msg(add_group_share(mk(), "region", "nope")),
                "no such column: nope"), "add_group_share checks its value")
check(identical(msg(summarise_by(mk(), c("zzz", "nope"),
                                 list(t = list(col = "sales", fn = sum)))),
                "no such column: zzz"),
      "the first missing name in argument order is reported")

# --- empty results keep their shape ------------------------------------
empty <- mk()[0, , drop = FALSE]
se <- summarise_by(empty, "region", list(total = list(col = "sales", fn = sum)))
check(identical(nrow(se), 0L), "no rows in, no groups out")
check(identical(names(se), c("region", "total")), "the columns still exist")
check(is.character(se$region), "the key column type survives")
check(is.double(se$total), "the summary column type survives")

ce <- count_by(empty, "region")
check(identical(nrow(ce), 0L), "count_by on an empty frame")
check(is.integer(ce$n), "n stays integer on an empty frame")

ge <- add_group_share(empty, "region", "sales")
check(identical(nrow(ge), 0L), "add_group_share on an empty frame")
check(identical(names(ge), c("region", "year", "sales", "share")),
      "share is still appended")

# --- every key missing --------------------------------------------------
allna <- mk()
allna$region <- NA_character_
sa <- summarise_by(allna, "region",
                   list(total = list(col = "sales", fn = sum)))
check(identical(nrow(sa), 0L), "no groups at all")
check(all(is.na(add_group_share(allna, "region", "sales")$share)),
      "every share is NA")

# --- keys are compared as character ------------------------------------
numkey <- data.frame(k = c(10, 9, 2, 10), v = c(1, 2, 3, 4))
sk <- summarise_by(numkey, "k", list(total = list(col = "v", fn = sum)))
check(near(sk$k, c(10, 2, 9)), "numeric keys order as character")
check(is.double(sk$k), "the key column keeps its numeric type")
check(near(sk$total, c(5, 3, 2)), "totals follow the character ordering")

cat("ok\n")
