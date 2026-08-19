# Missing-value handling for imported extracts.

na_report <- function(df) {
  n <- nrow(df)
  miss <- vapply(df, function(col) sum(is.na(col)), integer(1))
  data.frame(
    column = names(df),
    n_missing = as.integer(unname(miss)),
    pct_missing = if (n == 0L) rep(0, length(miss)) else as.numeric(unname(miss)) / n,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

complete_rows <- function(df) {
  if (ncol(df) == 0L) {
    return(rep(TRUE, nrow(df)))
  }
  bad <- Reduce(`|`, lapply(df, is.na))
  !bad
}

clean_frame <- function(df, policy = list()) {
  if (length(policy) > 0L) {
    nms <- names(policy)
    if (is.null(nms) || any(is.na(nms)) || any(nms == "")) {
      stop("every policy entry must be named", call. = FALSE)
    }
    missing_cols <- nms[!(nms %in% names(df))]
    if (length(missing_cols) > 0L) {
      stop(sprintf("no such column: %s", missing_cols[1L]), call. = FALSE)
    }
  }
  named <- names(policy)
  ordered_names <- names(df)[names(df) %in% named]

  # pass 1: drops, in column order
  for (nm in ordered_names) {
    if (identical(policy[[nm]], "drop")) {
      df <- df[!is.na(df[[nm]]), , drop = FALSE]
    }
  }

  # pass 2: fills, in column order, over the surviving rows
  for (nm in ordered_names) {
    p <- policy[[nm]]
    if (identical(p, "drop")) {
      next
    }
    col <- df[[nm]]
    if (is.character(p) && length(p) == 1L && !is.na(p) &&
        p %in% c("mean", "median")) {
      if (!is.numeric(col)) {
        stop(sprintf("column %s is not numeric", nm), call. = FALSE)
      }
      keep <- col[!is.na(col)]
      v <- if (p == "mean") mean(keep) else median(keep)
      col[is.na(col)] <- v
    } else if (is.list(p) && "fill" %in% names(p)) {
      col[is.na(col)] <- p[["fill"]]
    } else {
      stop(sprintf("unknown policy for column %s", nm), call. = FALSE)
    }
    df[[nm]] <- col
  }

  rownames(df) <- NULL
  df
}
