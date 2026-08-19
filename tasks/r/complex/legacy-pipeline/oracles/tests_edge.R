source("run.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# --- normalise_regions, on its own -------------------------------------
raw_frame <- data.frame(
  region = c("eastern", "north", "nrth", "south", "westerly"),
  price = c(1, 1, 1, 1, 1),
  stringsAsFactors = FALSE
)
nr <- normalise_regions(raw_frame)
check(is.character(nr$region), "region comes back as character")
check(identical(nr$region,
                c("east", "north", "north", "south", "westerly")),
      "every known misspelling is corrected and the rest are left alone")
check(!any(is.na(nr$region)), "nothing is blanked out")
check(identical(nrow(nr), 5L), "no rows are lost")

as_factor <- raw_frame
as_factor$region <- factor(as_factor$region)
nf <- normalise_regions(as_factor)
check(is.character(nf$region),
      "a factor region column is still returned as character")
check(identical(nf$region,
                c("east", "north", "north", "south", "westerly")),
      "and is corrected by label, not by level code")

# --- parse_qty, on its own ----------------------------------------------
pq <- parse_qty(c("12.5", "-", "0", "3", "0.25"))
check(is.double(pq), "parse_qty returns doubles")
check(near(pq, c(12.5, NA, 0, 3, 0.25)),
      "fractional amounts survive and the placeholder becomes NA")
check(is.na(pq[2]), "the placeholder is NA")
check(near(pq[3], 0), "a genuine zero is kept, not turned into NA")

pf <- parse_qty(factor(c("12.5", "-", "8")))
check(near(pf, c(12.5, NA, 8)),
      "a factor is read by label, never by level code")
check(is.double(pf), "and still gives doubles")

warned <- FALSE
invisible(withCallingHandlers(
  parse_qty(c("12.5", "-")),
  warning = function(w) {
    warned <<- TRUE
    invokeRestart("muffleWarning")
  }
))
check(!warned, "no warning may reach the caller")

# --- apply_weights looks the weight up by region -----------------------
one <- data.frame(region = "south", qty = 2, price = 5, revenue = 10,
                  stringsAsFactors = FALSE)
check(near(apply_weights(one)$weighted, 11),
      "a single southern row takes the southern weight")
check(identical(nrow(apply_weights(one)), 1L), "and stays one row")

two <- data.frame(region = c("north", "north"), qty = c(1, 1),
                  price = c(1, 1), revenue = c(10, 20),
                  stringsAsFactors = FALSE)
check(near(apply_weights(two)$weighted, c(10, 20)),
      "two rows of the same region share one multiplier")

unknown <- data.frame(region = c("west", "north"), qty = c(1, 1),
                      price = c(1, 1), revenue = c(10, 20),
                      stringsAsFactors = FALSE)
aw <- apply_weights(unknown)
check(is.na(aw$weighted[1]), "a region with no weight gives NA")
check(near(aw$weighted[2], 20), "and the known region is unaffected")

# --- the weight follows the row, not its position ----------------------
p <- prepare(load_sales())
order_a <- apply_weights(p)$weighted
shuffle <- c(4, 1, 5, 2, 6, 3)
order_b <- apply_weights(p[shuffle, , drop = FALSE])$weighted
check(near(order_b, order_a[shuffle]),
      "reordering the rows must not change any row's weighted value")

reversed <- apply_weights(p[6:1, , drop = FALSE])$weighted
check(near(reversed, order_a[6:1]),
      "and neither must reversing them")

# --- a row count that is not a multiple of the region count -----------
four <- p[1:4, , drop = FALSE]
t4 <- total_report(four)
check(identical(t4$rows, 4L), "the row count is what it was given")
check(near(t4$revenue, 133.75), "revenue over four rows")
check(near(t4$weighted, 145.5), "weighted revenue over four rows")

single <- total_report(p[4, , drop = FALSE])
check(identical(single$rows, 1L), "a one-row total")
check(near(single$revenue, 50), "its revenue")
check(near(single$weighted, 60), "its weighted revenue")

# --- region_report corner cases ----------------------------------------
nar <- data.frame(region = c(NA_character_, "north", NA_character_),
                  qty = c(1, 2, 3), price = c(1, 1, 1),
                  revenue = c(10, 20, 30), stringsAsFactors = FALSE)
rn <- region_report(nar)
check(identical(nrow(rn), 1L), "rows with no region form no group")
check(identical(rn$region, "north"), "only the real region appears")
check(identical(rn$rows, 1L), "and counts only its own row")
check(near(rn$revenue, 20), "NA-region revenue is excluded")

allna <- data.frame(region = c(NA_character_, NA_character_),
                    qty = c(1, 2), price = c(1, 1), revenue = c(1, 2),
                    stringsAsFactors = FALSE)
ra <- region_report(allna)
check(identical(nrow(ra), 0L), "no usable rows gives no rows")
check(identical(names(ra),
                c("region", "rows", "qty", "revenue", "weighted")),
      "the empty result keeps its columns")
check(is.character(ra$region), "and its region type")
check(is.integer(ra$rows), "and its row-count type")
check(is.double(ra$qty), "and its numeric types")

empty <- p[0, , drop = FALSE]
re <- region_report(empty)
check(identical(nrow(re), 0L), "an empty frame gives no rows")
check(identical(names(re),
                c("region", "rows", "qty", "revenue", "weighted")),
      "and still carries every column")

# --- a region with no weight still appears in the breakdown ----------
ru <- region_report(unknown)
check(identical(ru$region, c("north", "west")),
      "regions sorted ascending, weight or no weight")
check(near(ru$revenue, c(20, 10)), "revenue is reported for both")
check(near(ru$weighted, c(20, 0)),
      "an unweighted region totals to zero once its NA is ignored")

# --- an NA quantity does not sink its region's totals ----------------
gap <- region_report(p)
check(identical(gap$rows[3], 2L), "south still counts both of its rows")
check(near(gap$qty[3], 7), "but only the quantity it actually has")
check(near(gap$revenue[3], 17.5), "and only the revenue it actually has")

cat("ok\n")
