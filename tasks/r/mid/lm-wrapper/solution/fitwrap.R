# A tidy wrapper around lm: plain data frames on the way out.

fit_model <- function(data, formula) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame", call. = FALSE)
  }
  if (!inherits(formula, "formula")) {
    stop("formula must be a formula", call. = FALSE)
  }
  fit <- lm(formula, data = data)
  structure(
    list(
      fit = fit,
      formula = formula,
      nobs = length(fit$residuals)
    ),
    class = "fitwrap"
  )
}

.inner_fit <- function(model) {
  if (!inherits(model, "fitwrap")) {
    stop("expected a fitwrap object", call. = FALSE)
  }
  model$fit
}

tidy_coefs <- function(model) {
  fit <- .inner_fit(model)
  cm <- summary(fit)$coefficients
  data.frame(
    term = rownames(cm),
    estimate = as.numeric(cm[, 1L]),
    std_error = as.numeric(cm[, 2L]),
    statistic = as.numeric(cm[, 3L]),
    p_value = as.numeric(cm[, 4L]),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

glance_fit <- function(model) {
  fit <- .inner_fit(model)
  s <- summary(fit)
  data.frame(
    r_squared = as.numeric(s$r.squared),
    adj_r_squared = as.numeric(s$adj.r.squared),
    sigma = as.numeric(s$sigma),
    df_residual = as.integer(fit$df.residual),
    nobs = as.integer(length(fit$residuals)),
    row.names = NULL
  )
}

predict_frame <- function(model, newdata) {
  fit <- .inner_fit(model)
  out <- as.data.frame(newdata)
  rownames(out) <- NULL
  out[[".fitted"]] <- as.numeric(predict(fit, newdata = newdata))
  out
}

residual_summary <- function(model) {
  fit <- .inner_fit(model)
  r <- as.numeric(fit$residuals)
  q <- as.numeric(quantile(r, c(0, 0.25, 0.5, 0.75, 1), type = 7,
                           names = FALSE))
  data.frame(
    min = q[1L],
    q1 = q[2L],
    median = q[3L],
    q3 = q[4L],
    max = q[5L],
    row.names = NULL
  )
}
