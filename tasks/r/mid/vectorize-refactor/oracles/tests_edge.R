source("series.R")
.defined <- ls(envir = globalenv())

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

# --- no explicit loops survive anywhere in series.R --------------------
defined_fns <- Filter(
  function(n) is.function(get(n, envir = globalenv())),
  .defined
)
check(all(c("running_total", "pct_change", "rolling_mean", "zscore",
            "rolling_max", "ewma") %in% defined_fns),
      "all six functions must be defined in series.R")
loopy <- Filter(
  function(n) {
    tryCatch({
      txt <- paste(deparse(body(get(n, envir = globalenv()))), collapse = "\n")
      grepl("(^|[^[:alnum:]._])(for|while|repeat)([^[:alnum:]._]|$)", txt)
    }, error = function(e) FALSE)
  },
  defined_fns
)
check(length(loopy) == 0L,
      paste("explicit loop still present in:", paste(loopy, collapse = ", ")))

# --- NA handling is exactly what it was --------------------------------
na_in <- c(1, NA, 3, 4)
check(identical(is.na(running_total(na_in)), c(FALSE, TRUE, TRUE, TRUE)),
      "running_total carries an NA forward from where it appears")
check(near(running_total(na_in)[1], 1), "values before the NA are intact")

pc <- pct_change(na_in)
check(is.na(pc[1]) && is.na(pc[2]) && is.na(pc[3]),
      "pct_change is NA on either side of a gap")
check(near(pc[4], 1 / 3), "pct_change recovers after the gap")

rm2 <- rolling_mean(na_in, 2)
check(is.na(rm2[2]) && is.na(rm2[3]), "windows touching the NA are NA")
check(near(rm2[4], 3.5),
      "a window past the NA is a real number, not a smeared NA")

mx2 <- rolling_max(na_in, 2)
check(is.na(mx2[2]) && is.na(mx2[3]), "the same for rolling_max")
check(near(mx2[4], 4), "and it recovers past the gap too")

# --- zero-length input everywhere --------------------------------------
none <- numeric(0)
check(identical(running_total(none), numeric(0)), "running_total on empty")
check(identical(pct_change(none), numeric(0)), "pct_change on empty")
check(identical(rolling_mean(none, 3), numeric(0)), "rolling_mean on empty")
check(identical(rolling_max(none, 3), numeric(0)), "rolling_max on empty")
check(identical(zscore(none), numeric(0)), "zscore on empty")
check(identical(ewma(none, 0.5), numeric(0)), "ewma on empty")

# --- single-element input ------------------------------------------------
check(near(running_total(7), 7), "running_total of one value")
check(is.na(pct_change(7)), "pct_change of one value is NA")
check(near(rolling_mean(7, 1), 7), "rolling_mean of one value")
check(near(rolling_max(7, 1), 7), "rolling_max of one value")
check(is.na(rolling_mean(7, 2)), "a window bigger than one value")
check(all(is.na(zscore(7))), "zscore of one value")

# --- zero denominators stay NA, never infinite -------------------------
z <- pct_change(c(0, 5, 0, 5))
check(is.na(z[2]), "a zero previous value gives NA")
check(is.na(z[4]), "and again later in the series")
check(near(z[3], -1), "a real change is still computed")
check(!any(is.infinite(z), na.rm = TRUE), "no infinities anywhere")

# --- zscore degenerate cases -------------------------------------------
check(all(is.na(zscore(c(3, 3, 3, 3)))), "no spread gives all NA")
check(all(is.na(zscore(c(NA, 5, NA)))), "one usable value gives all NA")
check(all(is.na(zscore(c(NA_real_, NA_real_)))), "no usable values")
zn <- zscore(c(1, NA, 3))
check(is.na(zn[2]), "an NA element stays NA")
check(near(zn[c(1, 3)], c(-1, 1) / sd(c(1, 3)) * 1), "the rest are scored")
check(identical(length(zn), 3L), "zscore keeps the length")

# --- the error cases are unchanged -------------------------------------
check(identical(msg(rolling_mean(c(1, 2), 0)), "k must be at least 1"),
      "rolling_mean rejects k below one")
check(identical(msg(rolling_mean(c(1, 2), -3)), "k must be at least 1"),
      "and rejects a negative k")
check(identical(msg(ewma(c(1, 2), "x")), "alpha must be in (0, 1]"),
      "a non-numeric alpha is refused")
check(identical(msg(ewma(c(1, 2), c(0.2, 0.3))), "alpha must be in (0, 1]"),
      "two alphas are refused")
check(identical(msg(ewma(c(1, 2), NA_real_)), "alpha must be in (0, 1]"),
      "an NA alpha is refused")
check(is.na(msg(ewma(c(1, 2), 1))), "alpha of exactly one is allowed")

cat("ok\n")
