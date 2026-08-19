source("verbs.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

mk <- function() {
  data.frame(
    g = c("b", "a", "b", "c", "a", "b"),
    n = c(3L, 1L, 5L, 2L, 4L, 6L),
    v = c(10, 20, 30, 40, 50, 60),
    stringsAsFactors = FALSE
  )
}

# --- select_cols --------------------------------------------------------
s <- select_cols(mk(), v, g)
check(is.data.frame(s), "select_cols must return a data frame")
check(identical(names(s), c("v", "g")), "columns in the order written")
check(near(s$v, c(10, 20, 30, 40, 50, 60)), "the values travel with them")
check(identical(rownames(s), as.character(1:6)), "default row names")

s1 <- select_cols(mk(), n)
check(is.data.frame(s1), "a single column is still a data frame")
check(identical(names(s1), "n"), "the single column")
check(is.integer(s1$n), "its type is unchanged")

sd1 <- select_cols(mk(), -n)
check(identical(names(sd1), c("g", "v")),
      "a dropped column leaves the rest in their original order")
sd2 <- select_cols(mk(), -n, -g)
check(identical(names(sd2), "v"), "two dropped columns")

sstr <- select_cols(mk(), "v")
check(identical(names(sstr), "v"), "a string literal names a column too")

# --- filter_rows --------------------------------------------------------
f <- filter_rows(mk(), v > 25)
check(is.data.frame(f), "filter_rows must return a data frame")
check(identical(nrow(f), 4L), "four rows pass")
check(identical(f$n, c(5L, 2L, 4L, 6L)), "the right rows pass")
check(identical(names(f), c("g", "n", "v")), "every column is kept")
check(identical(rownames(f), as.character(1:4)), "default row names")

check(identical(filter_rows(mk(), g == "a")$n, c(1L, 4L)),
      "a character comparison")
check(identical(nrow(filter_rows(mk(), TRUE)), 6L),
      "a single TRUE keeps everything")
check(identical(nrow(filter_rows(mk(), n > 2 & v < 55)), 3L),
      "a compound condition")

# --- the caller's environment is the fallback --------------------------
threshold <- 25
ft <- filter_rows(mk(), v > threshold)
check(identical(nrow(ft), 4L), "a local variable resolves in the condition")
check(identical(ft$n, c(5L, 2L, 4L, 6L)), "and gives the right rows")

# --- mutate_cols --------------------------------------------------------
m <- mutate_cols(mk(), double_v = v * 2, ratio = double_v / n)
check(is.data.frame(m), "mutate_cols must return a data frame")
check(identical(names(m), c("g", "n", "v", "double_v", "ratio")),
      "new columns are appended in order")
check(near(m$double_v, c(20, 40, 60, 80, 100, 120)), "the first mutation")
check(near(m$ratio, c(20 / 3, 40, 12, 40, 25, 20)),
      "the second mutation can see the first")
check(identical(rownames(m), as.character(1:6)), "default row names")

mr <- mutate_cols(mk(), n = n + 1L)
check(identical(names(mr), c("g", "n", "v")),
      "replacing a column keeps its position")
check(identical(mr$n, c(4L, 2L, 6L, 3L, 5L, 7L)), "the replaced values")

msc <- mutate_cols(mk(), tag = "x")
check(identical(msc$tag, rep("x", 6)), "a single value is recycled")

# --- arrange_rows -------------------------------------------------------
a <- arrange_rows(mk(), g, n)
check(is.data.frame(a), "arrange_rows must return a data frame")
check(identical(a$g, c("a", "a", "b", "b", "b", "c")), "the primary key")
check(identical(a$n, c(1L, 4L, 3L, 5L, 6L, 2L)), "the secondary key")
check(near(a$v, c(20, 50, 10, 30, 60, 40)), "the payload follows its rows")
check(identical(rownames(a), as.character(1:6)), "default row names")

ad <- arrange_rows(mk(), desc(v))
check(near(ad$v, c(60, 50, 40, 30, 20, 10)), "desc sorts downwards")
check(identical(ad$n, c(6L, 4L, 2L, 5L, 1L, 3L)), "the rows moved with it")

as1 <- arrange_rows(mk(), g)
check(identical(as1$n, c(1L, 4L, 3L, 5L, 6L, 2L)),
      "the sort is stable: tied rows keep their original order")

# --- summarise_groups ---------------------------------------------------
sg <- summarise_groups(mk(), "g", total = sum(v), n_rows = length(v))
check(is.data.frame(sg), "summarise_groups must return a data frame")
check(identical(names(sg), c("g", "total", "n_rows")),
      "key column then the summaries in order")
check(identical(sg$g, c("a", "b", "c")), "groups sorted ascending")
check(near(sg$total, c(70, 100, 40)), "grouped totals")
check(near(sg$n_rows, c(2, 3, 1)), "grouped counts")
check(is.double(sg$total) && is.double(sg$n_rows),
      "summary columns are always double")
check(identical(rownames(sg), c("1", "2", "3")), "default row names")

d2 <- data.frame(g = c("a", "a", "b", "b"), h = c("x", "y", "x", "y"),
                 v = c(1, 2, 3, 4), stringsAsFactors = FALSE)
sg2 <- summarise_groups(d2, c("g", "h"), total = sum(v))
check(identical(names(sg2), c("g", "h", "total")), "two key columns")
check(identical(nrow(sg2), 4L), "four groups")
check(identical(sg2$g, c("a", "a", "b", "b")), "primary key ordering")
check(identical(sg2$h, c("x", "y", "x", "y")), "secondary key ordering")
check(near(sg2$total, c(1, 2, 3, 4)), "the group totals")

# --- the verbs chain with the native pipe ------------------------------
res <- mk() |>
  filter_rows(v > 15) |>
  arrange_rows(desc(n)) |>
  select_cols(g, n)
check(is.data.frame(res), "a piped chain returns a data frame")
check(identical(names(res), c("g", "n")), "the final selection")
check(identical(res$n, c(6L, 5L, 4L, 2L, 1L)), "the chained result")
check(identical(res$g, c("b", "b", "a", "c", "a")), "and its labels")

cat("ok\n")
