# Composable data-frame verbs, base R only.

.SEP <- rawToChar(as.raw(31L))

.renumber <- function(df) {
  rownames(df) <- NULL
  df
}

.col_name <- function(e) {
  if (is.name(e)) {
    return(as.character(e))
  }
  if (is.character(e) && length(e) == 1L) {
    return(e)
  }
  stop("column selections must be names", call. = FALSE)
}

.require_cols <- function(df, needed) {
  miss <- needed[!(needed %in% names(df))]
  if (length(miss) > 0L) {
    stop(sprintf("no such column: %s", miss[[1L]]), call. = FALSE)
  }
  invisible(TRUE)
}

select_cols <- function(df, ...) {
  exprs <- as.list(substitute(list(...)))[-1L]
  if (length(exprs) == 0L) {
    stop("select_cols needs at least one column", call. = FALSE)
  }
  dropped <- vapply(
    exprs,
    function(e) is.call(e) && identical(e[[1L]], as.name("-")),
    logical(1)
  )
  if (any(dropped) && !all(dropped)) {
    stop("cannot mix kept and dropped columns", call. = FALSE)
  }
  named <- vapply(
    seq_along(exprs),
    function(i) {
      e <- exprs[[i]]
      .col_name(if (dropped[[i]]) e[[2L]] else e)
    },
    character(1)
  )
  .require_cols(df, named)
  keep <- if (all(dropped)) setdiff(names(df), named) else named
  .renumber(df[, keep, drop = FALSE])
}

filter_rows <- function(df, condition) {
  cond <- as.logical(eval(substitute(condition), df, parent.frame()))
  if (length(cond) == 1L) {
    cond <- rep(cond, nrow(df))
  }
  if (length(cond) != nrow(df)) {
    stop("condition must give one value per row", call. = FALSE)
  }
  cond[is.na(cond)] <- FALSE
  .renumber(df[cond, , drop = FALSE])
}

mutate_cols <- function(df, ...) {
  exprs <- as.list(substitute(list(...)))[-1L]
  if (length(exprs) == 0L) {
    return(.renumber(df))
  }
  nms <- names(exprs)
  if (is.null(nms) || any(is.na(nms)) || any(nms == "")) {
    stop("every mutation must be named", call. = FALSE)
  }
  out <- .renumber(df)
  env <- parent.frame()
  for (i in seq_along(exprs)) {
    value <- eval(exprs[[i]], out, env)
    if (length(value) == 1L) {
      value <- rep(value, nrow(out))
    }
    if (length(value) != nrow(out)) {
      stop(sprintf("column %s has the wrong length", nms[[i]]),
           call. = FALSE)
    }
    out[[nms[[i]]]] <- value
  }
  out
}

desc <- function(x) {
  x
}

arrange_rows <- function(df, ...) {
  exprs <- as.list(substitute(list(...)))[-1L]
  if (length(exprs) == 0L) {
    stop("arrange_rows needs at least one column", call. = FALSE)
  }
  descending <- vapply(
    exprs,
    function(e) is.call(e) && identical(e[[1L]], as.name("desc")),
    logical(1)
  )
  named <- vapply(
    seq_along(exprs),
    function(i) {
      e <- exprs[[i]]
      .col_name(if (descending[[i]]) e[[2L]] else e)
    },
    character(1)
  )
  .require_cols(df, named)
  keys <- lapply(seq_along(named), function(i) {
    rank <- xtfrm(df[[named[[i]]]])
    if (descending[[i]]) -rank else rank
  })
  ord <- do.call(order, c(keys, list(method = "radix")))
  .renumber(df[ord, , drop = FALSE])
}

summarise_groups <- function(df, by, ...) {
  exprs <- as.list(substitute(list(...)))[-1L]
  if (length(exprs) == 0L) {
    stop("summarise_groups needs at least one summary", call. = FALSE)
  }
  nms <- names(exprs)
  if (is.null(nms) || any(is.na(nms)) || any(nms == "")) {
    stop("every summary must be named", call. = FALSE)
  }
  .require_cols(df, by)
  env <- parent.frame()

  keys <- lapply(by, function(b) as.character(df[[b]]))
  keep <- !Reduce(`|`, lapply(keys, is.na))
  d <- df[keep, , drop = FALSE]
  keys <- lapply(keys, function(k) k[keep])

  if (nrow(d) == 0L) {
    out <- .renumber(d[, by, drop = FALSE])
    for (nm in nms) {
      out[[nm]] <- numeric(0)
    }
    return(out)
  }

  gid <- do.call(paste, c(keys, list(sep = .SEP)))
  ord <- do.call(order, keys)
  firsts <- ord[!duplicated(gid[ord])]
  labels <- gid[firsts]

  out <- .renumber(d[firsts, by, drop = FALSE])
  for (i in seq_along(exprs)) {
    out[[nms[[i]]]] <- vapply(
      labels,
      function(g) as.numeric(eval(exprs[[i]], d[gid == g, , drop = FALSE], env)),
      numeric(1),
      USE.NAMES = FALSE
    )
  }
  out
}
