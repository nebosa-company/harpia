source("run.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# --- stage 1: text stays text ------------------------------------------
raw <- load_sales()
check(is.data.frame(raw), "load_sales must return a data frame")
check(identical(nrow(raw), 6L), "every row of the extract is read")
check(is.character(raw$region), "region is read as character")
check(is.character(raw$product), "product is read as character")
check(is.character(raw$qty), "the quantity column arrives as text")
check(is.numeric(raw$price), "price is numeric")

# --- stage 2: regions, quantities, revenue -----------------------------
p <- prepare(raw)
check(is.character(p$region), "region stays character after preparing")
check(identical(p$region,
                c("north", "south", "north", "east", "south", "north")),
      "the misspelt region is corrected, not blanked out")
check(!any(is.na(p$region)), "no row loses its region")

check(is.double(p$qty), "the quantity becomes a double")
check(near(p$qty, c(12.5, 7, 3.5, 20, NA, 8)),
      "the recorded amounts, half units intact")
check(is.na(p$qty[5]), "the placeholder becomes NA")

check(near(p$revenue, c(31.25, 17.5, 35, 50, NA, 20)),
      "revenue is quantity times price")
check(identical(nrow(p), 6L), "preparing keeps every row")

# --- stage 3: weighting by region --------------------------------------
w <- apply_weights(p)
check("weighted" %in% names(w), "apply_weights adds a weighted column")
check(near(w$weighted, c(31.25, 19.25, 35, 60, NA, 20)),
      "each row is weighted by its own region's multiplier")
check(identical(nrow(w), 6L), "weighting keeps every row")

# --- the end-to-end total ----------------------------------------------
t <- run_pipeline()
check(is.data.frame(t), "run_pipeline must return a data frame")
check(identical(names(t), c("rows", "revenue", "weighted")),
      "the total report's columns")
check(identical(nrow(t), 1L), "one row of totals")
check(identical(t$rows, 6L), "the row count")
check(is.integer(t$rows), "the row count is an integer")
check(near(t$revenue, 153.75), "total revenue")
check(near(t$weighted, 165.5), "total weighted revenue")
check(is.double(t$revenue) && is.double(t$weighted),
      "the totals are doubles")

# --- the new regional breakdown ----------------------------------------
r <- run_region_report()
check(is.data.frame(r), "run_region_report must return a data frame")
check(identical(names(r),
                c("region", "rows", "qty", "revenue", "weighted")),
      "the regional report's columns, in order")
check(identical(nrow(r), 3L), "one row per region present")
check(identical(r$region, c("east", "north", "south")),
      "regions sorted ascending, with the corrected label included")
check(is.character(r$region), "region is character")
check(identical(r$rows, c(1L, 3L, 2L)), "how many rows each region has")
check(is.integer(r$rows), "the row counts are integers")
check(near(r$qty, c(20, 24, 7)), "quantity per region, ignoring the gap")
check(near(r$revenue, c(50, 86.25, 17.5)), "revenue per region")
check(near(r$weighted, c(60, 86.25, 19.25)), "weighted revenue per region")
check(all(vapply(r[3:5], is.double, logical(1))),
      "the three totals are doubles")
check(identical(rownames(r), c("1", "2", "3")), "default row names")

# --- the two reports agree ---------------------------------------------
check(near(sum(r$revenue), t$revenue),
      "the regional revenues add up to the total")
check(near(sum(r$weighted), t$weighted),
      "the regional weighted revenues add up to the total")
check(identical(sum(r$rows), t$rows), "the row counts add up")

# --- region_report can be called on a prepared frame directly ----------
direct <- region_report(prepare(load_sales()))
check(identical(direct, r), "region_report and run_region_report agree")

cat("ok\n")
