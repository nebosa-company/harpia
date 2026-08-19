# Package-free reshaping.

.SEP <- rawToChar(as.raw(31L))

.require_cols <- function(df, needed) {
  miss <- needed[!(needed %in% names(df))]
  if (length(miss) > 0L) {
    stop(sprintf("no such column: %s", miss[[1L]]), call. = FALSE)
  }
  invisible(TRUE)
}

to_long <- function(df, id_cols, value_cols, name_to = "name",
                    value_to = "value") {
  .require_cols(df, c(id_cols, value_cols))
  if (length(value_cols) == 0L) {
    stop("value_cols must not be empty", call. = FALSE)
  }
  n <- nrow(df)
  k <- length(value_cols)
  cols <- lapply(value_cols, function(cn) df[[cn]])

  out <- df[rep(seq_len(n), each = k), id_cols, drop = FALSE]
  rownames(out) <- NULL

  if (n == 0L) {
    out[[name_to]] <- character(0)
    out[[value_to]] <- do.call(c, lapply(cols, function(z) z[0L]))
    return(out)
  }

  out[[name_to]] <- rep(value_cols, times = n)
  flat <- do.call(c, cols)
  # flat is column-major; walk the index matrix row-wise to get row-major.
  out[[value_to]] <- flat[as.vector(t(matrix(seq_len(n * k), nrow = n)))]
  out
}

to_wide <- function(df, id_cols, name_from, value_from, fill = NA) {
  .require_cols(df, c(id_cols, name_from, value_from))
  keys <- lapply(id_cols, function(b) as.character(df[[b]]))
  gid <- do.call(paste, c(keys, list(sep = .SEP)))
  groups <- unique(gid)
  firsts <- match(groups, gid)

  out <- df[firsts, id_cols, drop = FALSE]
  rownames(out) <- NULL

  labels <- as.character(df[[name_from]])
  v <- df[[value_from]]
  for (cn in unique(labels)) {
    sel <- which(labels == cn)
    pos <- match(gid[sel], groups)
    if (anyDuplicated(pos) > 0L) {
      stop(sprintf("duplicate cell in column %s", cn), call. = FALSE)
    }
    col <- rep(fill, length(groups))
    col[pos] <- v[sel]
    out[[cn]] <- col
  }
  out
}

transpose_frame <- function(df, id_col) {
  .require_cols(df, id_col)
  others <- setdiff(names(df), id_col)
  labels <- as.character(df[[id_col]])
  if (anyDuplicated(labels) > 0L) {
    stop("duplicate row labels", call. = FALSE)
  }
  out <- data.frame(name = others, stringsAsFactors = FALSE, row.names = NULL)
  for (i in seq_along(labels)) {
    out[[labels[i]]] <- vapply(
      others,
      function(cn) as.character(df[[cn]][i]),
      character(1),
      USE.NAMES = FALSE
    )
  }
  out
}
