# Grouped summaries, base R only.

# A separator that cannot turn up in ordinary key text, so several key
# columns can be pasted into one group id without becoming ambiguous.
.SEP <- rawToChar(as.raw(31L))

.require_cols <- function(df, needed) {
  miss <- needed[!(needed %in% names(df))]
  if (length(miss) > 0L) {
    stop(sprintf("no such column: %s", miss[[1L]]), call. = FALSE)
  }
  invisible(TRUE)
}

.key_parts <- function(df, by) {
  lapply(by, function(b) as.character(df[[b]]))
}

summarise_by <- function(df, by, specs) {
  spec_cols <- if (length(specs) > 0L) {
    vapply(specs, function(s) s$col, character(1), USE.NAMES = FALSE)
  } else {
    character(0)
  }
  .require_cols(df, c(by, spec_cols))

  keys <- .key_parts(df, by)
  keep <- !Reduce(`|`, lapply(keys, is.na))
  d <- df[keep, , drop = FALSE]
  keys <- lapply(keys, function(k) k[keep])

  if (nrow(d) == 0L) {
    out <- d[, by, drop = FALSE]
    rownames(out) <- NULL
    for (nm in names(specs)) {
      out[[nm]] <- numeric(0)
    }
    return(out)
  }

  gid <- do.call(paste, c(keys, list(sep = .SEP)))
  ord <- do.call(order, keys)
  firsts <- ord[!duplicated(gid[ord])]
  labels <- gid[firsts]

  out <- d[firsts, by, drop = FALSE]
  rownames(out) <- NULL
  for (nm in names(specs)) {
    s <- specs[[nm]]
    v <- d[[s$col]]
    out[[nm]] <- vapply(
      labels,
      function(g) as.numeric(s$fn(v[gid == g])),
      numeric(1),
      USE.NAMES = FALSE
    )
  }
  out
}

count_by <- function(df, by) {
  .require_cols(df, by)
  d <- df
  d[[".count_one"]] <- rep(1, nrow(d))
  out <- summarise_by(d, by, list(n = list(col = ".count_one", fn = sum)))
  out$n <- as.integer(out$n)
  out
}

add_group_share <- function(df, by, value) {
  .require_cols(df, c(by, value))
  out <- df
  rownames(out) <- NULL
  if (nrow(df) == 0L) {
    out$share <- numeric(0)
    return(out)
  }
  keys <- .key_parts(df, by)
  gid <- do.call(paste, c(keys, list(sep = .SEP)))
  ungrouped <- Reduce(`|`, lapply(keys, is.na))
  v <- as.numeric(df[[value]])
  totals <- tapply(v, gid, function(z) sum(z, na.rm = TRUE))
  tot <- as.numeric(totals[gid])
  share <- v / tot
  share[!is.na(tot) & tot == 0] <- NA_real_
  share[ungrouped] <- NA_real_
  out$share <- as.numeric(share)
  out
}
