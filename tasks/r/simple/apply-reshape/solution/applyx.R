# Reshaping helpers, apply-family only: no explicit loops in this file.

col_summary <- function(df) {
  is_num <- vapply(df, is.numeric, logical(1))
  cols <- names(df)[is_num]
  one <- function(nm) {
    v <- df[[nm]]
    v <- v[!is.na(v)]
    n <- length(v)
    if (n == 0L) {
      c(n = 0, mean = NA_real_, sd = NA_real_, min = NA_real_, max = NA_real_)
    } else {
      c(n = n,
        mean = mean(v),
        sd = if (n >= 2L) sd(v) else NA_real_,
        min = min(v),
        max = max(v))
    }
  }
  proto <- c(n = 0, mean = 0, sd = 0, min = 0, max = 0)
  m <- vapply(cols, one, proto)
  data.frame(
    column = cols,
    n = as.integer(m["n", ]),
    mean = as.numeric(m["mean", ]),
    sd = as.numeric(m["sd", ]),
    min = as.numeric(m["min", ]),
    max = as.numeric(m["max", ]),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

matrix_to_long <- function(m) {
  if (!is.matrix(m)) {
    stop("expected a matrix", call. = FALSE)
  }
  rn <- rownames(m)
  cn <- colnames(m)
  if (is.null(rn) || is.null(cn)) {
    stop("matrix needs row and column names", call. = FALSE)
  }
  data.frame(
    row = rep(rn, times = ncol(m)),
    col = rep(cn, each = nrow(m)),
    value = as.vector(m),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

group_apply <- function(df, by, col, f) {
  keys <- as.character(df[[by]])
  lv <- sort(unique(keys[!is.na(keys)]))
  parts <- split(df[[col]], factor(keys, levels = lv))
  vals <- vapply(parts, function(v) as.numeric(f(v)), numeric(1))
  out <- data.frame(
    .group = lv,
    value = unname(vals),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  names(out)[1L] <- by
  out
}
