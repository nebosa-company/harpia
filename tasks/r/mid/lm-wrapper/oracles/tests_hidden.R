source("fitwrap.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-8))

d <- data.frame(
  x = c(1, 2, 3, 4, 5, 6, 7, 8),
  z = c(2, 1, 4, 3, 6, 5, 8, 7),
  y = c(3.1, 4.9, 7.2, 8.8, 11.1, 12.9, 15.2, 16.8)
)

ref <- lm(y ~ x, data = d)
rs <- summary(ref)
m <- fit_model(d, y ~ x)

# --- the wrapper object -------------------------------------------------
check(inherits(m, "fitwrap"), "fit_model must set the class")
check(is.list(m), "a fitwrap is a list")
check(identical(names(m), c("fit", "formula", "nobs")),
      "the element names, in order")
check(inherits(m$fit, "lm"), "the lm object is carried along")
check(inherits(m$formula, "formula"), "the formula is carried along")
check(identical(m$nobs, 8L), "eight observations were used")
check(is.integer(m$nobs), "nobs is an integer")
check(near(unname(coef(m$fit)), unname(coef(ref))),
      "the wrapped fit matches a plain lm")

# --- tidy_coefs ---------------------------------------------------------
tc <- tidy_coefs(m)
check(is.data.frame(tc), "tidy_coefs must return a data frame")
check(identical(names(tc),
                c("term", "estimate", "std_error", "statistic", "p_value")),
      "tidy_coefs column names")
check(identical(tc$term, c("(Intercept)", "x")), "terms in model order")
check(is.character(tc$term), "term is character")
check(identical(nrow(tc), 2L), "one row per coefficient")
check(near(tc$estimate, unname(rs$coefficients[, 1])), "estimates")
check(near(tc$std_error, unname(rs$coefficients[, 2])), "standard errors")
check(near(tc$statistic, unname(rs$coefficients[, 3])), "t statistics")
check(near(tc$p_value, unname(rs$coefficients[, 4])), "p values")
check(is.null(names(tc$estimate)), "the numeric columns carry no names")
check(all(vapply(tc[-1], is.double, logical(1))),
      "every numeric column is double")
check(identical(rownames(tc), c("1", "2")), "default row names")
check(near(tc$estimate[1], 1.064285714286), "the fitted intercept")
check(near(tc$estimate[2], 1.985714285714), "the fitted slope")

# --- two predictors keep their order ------------------------------------
m2 <- fit_model(d, y ~ x + z)
tc2 <- tidy_coefs(m2)
check(identical(tc2$term, c("(Intercept)", "x", "z")),
      "terms follow the formula's order")
check(identical(nrow(tc2), 3L), "three coefficients")

# --- glance_fit ---------------------------------------------------------
g <- glance_fit(m)
check(is.data.frame(g), "glance_fit must return a data frame")
check(identical(names(g),
                c("r_squared", "adj_r_squared", "sigma", "df_residual",
                  "nobs")),
      "glance_fit column names")
check(identical(nrow(g), 1L), "one row")
check(near(g$r_squared, rs$r.squared), "r squared")
check(near(g$adj_r_squared, rs$adj.r.squared), "adjusted r squared")
check(near(g$sigma, rs$sigma), "residual standard error")
check(identical(g$df_residual, 6L), "residual degrees of freedom")
check(identical(g$nobs, 8L), "observation count")
check(is.integer(g$df_residual) && is.integer(g$nobs),
      "the two counts are integers")
check(is.double(g$r_squared), "r squared is a double")
check(identical(rownames(g), "1"), "default row name")

# --- predict_frame ------------------------------------------------------
nd <- data.frame(x = c(9, 10), z = c(1, 2))
pf <- predict_frame(m, nd)
check(is.data.frame(pf), "predict_frame must return a data frame")
check(identical(names(pf), c("x", "z", ".fitted")),
      "newdata's columns then .fitted")
check(identical(nrow(pf), 2L), "one row per newdata row")
check(near(pf$x, c(9, 10)), "newdata is passed through unchanged")
check(near(pf$z, c(1, 2)), "every newdata column survives")
check(is.double(pf$.fitted), ".fitted is a double")
check(is.null(names(pf$.fitted)), ".fitted carries no names")
check(near(pf$.fitted, unname(predict(ref, newdata = nd))), "the predictions")
check(identical(rownames(pf), c("1", "2")), "default row names")

# --- residual_summary ---------------------------------------------------
rsum <- residual_summary(m)
check(is.data.frame(rsum), "residual_summary must return a data frame")
check(identical(names(rsum), c("min", "q1", "median", "q3", "max")),
      "residual_summary column names")
check(identical(nrow(rsum), 1L), "one row")
qq <- unname(quantile(as.numeric(residuals(ref)),
                      c(0, 0.25, 0.5, 0.75, 1), type = 7))
check(near(as.numeric(rsum[1, ]), qq), "the five-number summary")
check(all(vapply(rsum, is.double, logical(1))), "every column is double")
check(is.null(names(rsum$min)), "no leftover names")

cat("ok\n")
