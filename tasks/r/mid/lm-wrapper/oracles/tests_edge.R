source("fitwrap.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-8))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}

d <- data.frame(
  x = c(1, 2, 3, 4, 5, 6, 7, 8),
  y = c(3.1, 4.9, 7.2, 8.8, 11.1, 12.9, 15.2, 16.8)
)

# --- argument validation -------------------------------------------------
check(identical(msg(fit_model(list(a = 1), y ~ x)),
                "data must be a data frame"), "a list is not a data frame")
check(identical(msg(fit_model(d, "y ~ x")), "formula must be a formula"),
      "a string is not a formula")
check(identical(msg(tidy_coefs(lm(y ~ x, data = d))),
                "expected a fitwrap object"),
      "a bare lm is not a fitwrap")
check(identical(msg(glance_fit(42)), "expected a fitwrap object"),
      "glance_fit checks its argument")
check(identical(msg(predict_frame(NULL, d)), "expected a fitwrap object"),
      "predict_frame checks its argument")
check(identical(msg(residual_summary(list())), "expected a fitwrap object"),
      "residual_summary checks its argument")

# --- nobs counts the rows the fit actually used ------------------------
gappy <- d
gappy$y[c(2, 5)] <- NA
mg <- fit_model(gappy, y ~ x)
check(identical(mg$nobs, 6L), "rows with a missing response are dropped")
check(identical(glance_fit(mg)$nobs, 6L), "glance_fit agrees")
check(identical(glance_fit(mg)$df_residual, 4L), "the degrees of freedom")
check(!identical(mg$nobs, nrow(gappy)),
      "nobs is not simply the number of input rows")

gapx <- d
gapx$x[1] <- NA
check(identical(fit_model(gapx, y ~ x)$nobs, 7L),
      "a missing predictor also drops its row")

# --- a model with no intercept ------------------------------------------
noint <- fit_model(d, y ~ x - 1)
tci <- tidy_coefs(noint)
check(identical(nrow(tci), 1L), "one coefficient without an intercept")
check(identical(tci$term, "x"), "the single term")
check(identical(glance_fit(noint)$df_residual, 7L),
      "one more residual degree of freedom")

# --- a factor predictor expands into named levels ---------------------
fd <- data.frame(
  g = factor(c("a", "b", "c", "a", "b", "c")),
  y = c(1, 4, 9, 2, 5, 10)
)
mf <- fit_model(fd, y ~ g)
tcf <- tidy_coefs(mf)
check(identical(tcf$term, c("(Intercept)", "gb", "gc")),
      "the factor's dummy terms are named after its levels")
check(is.character(tcf$term), "term stays character with a factor predictor")
check(identical(nrow(tcf), 3L), "three coefficients")

# --- predicting a single row --------------------------------------------
m <- fit_model(d, y ~ x)
one <- predict_frame(m, data.frame(x = 4))
check(is.data.frame(one), "one row of newdata is still a data frame")
check(identical(nrow(one), 1L), "one prediction")
check(identical(names(one), c("x", ".fitted")), "the columns")
check(near(one$.fitted, unname(predict(lm(y ~ x, data = d),
                                       newdata = data.frame(x = 4)))),
      "the single prediction")

# --- newdata's own row names are replaced ------------------------------
odd <- data.frame(x = c(1, 2))
rownames(odd) <- c("p", "q")
po <- predict_frame(m, odd)
check(identical(rownames(po), c("1", "2")), "row names are renumbered")
check(near(po$x, c(1, 2)), "the values still line up")

# --- extra columns in newdata are carried through ----------------------
extra <- data.frame(x = c(1, 2), label = c("first", "second"),
                    stringsAsFactors = FALSE)
pe <- predict_frame(m, extra)
check(identical(names(pe), c("x", "label", ".fitted")),
      "columns the model does not use are still returned, in order")
check(identical(pe$label, c("first", "second")),
      "their values are untouched")
check(is.character(pe$label), "and their types")

# --- residual_summary is ordered and consistent ------------------------
rsum <- residual_summary(m)
vals <- as.numeric(rsum[1, ])
check(all(diff(vals) >= -1e-12), "the five numbers are non-decreasing")
check(near(vals[1], min(residuals(lm(y ~ x, data = d)))), "the minimum")
check(near(vals[5], max(residuals(lm(y ~ x, data = d)))), "the maximum")
check(near(sum(residuals(lm(y ~ x, data = d))), 0),
      "residuals of a model with an intercept sum to zero")

cat("ok\n")
