source("groupby.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

mk <- function() {
  data.frame(
    region = c("north", "south", "north", "east", "south", "north"),
    year   = c(2023L, 2023L, 2024L, 2023L, 2024L, 2024L),
    sales  = c(10, 20, 30, 40, 50, 60),
    units  = c(1L, 2L, 3L, 4L, 5L, 6L),
    stringsAsFactors = FALSE
  )
}

# --- one grouping key ---------------------------------------------------
s <- summarise_by(mk(), "region",
                  list(total = list(col = "sales", fn = sum),
                       n = list(col = "sales", fn = length)))
check(is.data.frame(s), "summarise_by must return a data frame")
check(identical(names(s), c("region", "total", "n")),
      "key column first, then the specs in spec order")
check(identical(s$region, c("east", "north", "south")),
      "groups sorted ascending by the key")
check(near(s$total, c(40, 100, 70)), "grouped totals")
check(near(s$n, c(1, 3, 2)), "grouped counts")
check(is.double(s$total) && is.double(s$n),
      "summary columns are always double")
check(identical(rownames(s), c("1", "2", "3")), "default row names")

# --- two grouping keys, and the key types survive ----------------------
s2 <- summarise_by(mk(), c("region", "year"),
                   list(total = list(col = "sales", fn = sum)))
check(identical(names(s2), c("region", "year", "total")), "both keys first")
check(identical(nrow(s2), 5L), "five distinct region/year pairs")
check(identical(s2$region, c("east", "north", "north", "south", "south")),
      "primary key ordering")
check(identical(s2$year, c(2023L, 2023L, 2024L, 2023L, 2024L)),
      "secondary key ordering")
check(is.integer(s2$year), "an integer key column stays integer")
check(near(s2$total, c(40, 10, 90, 20, 50)), "totals per pair")

# --- a spec may use any function returning one number ------------------
s3 <- summarise_by(mk(), "region",
                   list(avg = list(col = "sales", fn = mean),
                        top = list(col = "units", fn = max)))
check(identical(names(s3), c("region", "avg", "top")), "spec order is kept")
check(near(s3$avg, c(40, 100 / 3, 35)), "grouped means")
check(near(s3$top, c(4, 6, 5)), "grouped maxima")
check(is.double(s3$top), "an integer-valued summary is still double")

# --- count_by -----------------------------------------------------------
c1 <- count_by(mk(), "region")
check(identical(names(c1), c("region", "n")), "count_by column names")
check(identical(c1$region, c("east", "north", "south")), "count_by ordering")
check(identical(c1$n, c(1L, 3L, 2L)), "group sizes")
check(is.integer(c1$n), "n must be integer")

c2 <- count_by(mk(), c("region", "year"))
check(identical(nrow(c2), 5L), "five pairs")
check(identical(c2$n, c(1L, 1L, 2L, 1L, 1L)), "pair sizes")
check(is.integer(c2$year), "the key type survives count_by")

# --- add_group_share ----------------------------------------------------
g <- add_group_share(mk(), "region", "sales")
check(is.data.frame(g), "add_group_share must return a data frame")
check(identical(names(g), c("region", "year", "sales", "units", "share")),
      "share is appended after the original columns")
check(identical(nrow(g), 6L), "no rows added or lost")
check(identical(g$region, mk()$region), "the original row order is kept")
check(near(g$share, c(10 / 100, 20 / 70, 30 / 100, 1, 50 / 70, 60 / 100)),
      "each row's share of its group total")
check(is.double(g$share), "share must be double")
check(identical(rownames(g), as.character(1:6)), "default row names")

g2 <- add_group_share(mk(), c("region", "year"), "sales")
check(near(g2$share, c(1, 1, 30 / 90, 1, 1, 60 / 90)),
      "shares within region/year pairs")

cat("ok\n")
