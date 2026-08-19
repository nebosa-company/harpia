source("levels.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)

# --- set_order builds an ordered factor with the given level sequence ---
x <- c("med", "low", "high", "med", "zzz")
f <- set_order(x, c("low", "med", "high"))
check(is.factor(f), "set_order must return a factor")
check(is.ordered(f), "set_order must return an ordered factor")
check(identical(levels(f), c("low", "med", "high")), "levels must be `order`")
check(identical(as.character(f), c("med", "low", "high", "med", NA)),
      "unlisted values become NA")
check(isTRUE(f[2] < f[1]), "low must compare below med")
check(isTRUE(f[1] < f[3]), "med must compare below high")
check(identical(length(f), 5L), "length is preserved")

# --- level_counts ------------------------------------------------------
lc <- level_counts(f)
check(is.data.frame(lc), "level_counts must return a data frame")
check(identical(names(lc), c("level", "count")), "column names")
check(is.character(lc$level), "level column must be character")
check(is.integer(lc$count), "count column must be integer")
check(identical(lc$level, c("low", "med", "high")), "rows follow level order")
check(identical(lc$count, c(1L, 2L, 1L)), "counts exclude NA")
check(identical(rownames(lc), c("1", "2", "3")), "default row names")

# --- numeric_codes reads labels, not internal codes --------------------
g <- factor(c("10", "20", "10", "30"))
nc <- numeric_codes(g)
check(is.double(nc), "numeric_codes must return a double vector")
check(isTRUE(all.equal(nc, c(10, 20, 10, 30), tolerance = 1e-9)),
      "labels, not codes")
check(!identical(as.numeric(as.integer(g)), nc),
      "the internal codes are not the answer")

h <- factor(c("2021", "2022", "2021"))
check(isTRUE(all.equal(numeric_codes(h), c(2021, 2022, 2021), tolerance = 1e-9)),
      "year labels")

cat("ok\n")
