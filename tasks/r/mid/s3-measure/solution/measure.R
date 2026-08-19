# An S3 measurement class: a double vector plus a `unit` attribute.

measure <- function(value, unit) {
  if (!is.numeric(value)) {
    stop("value must be numeric", call. = FALSE)
  }
  if (!is.character(unit) || length(unit) != 1L || is.na(unit) ||
      !nzchar(unit)) {
    stop("unit must be a single non-empty string", call. = FALSE)
  }
  structure(as.numeric(value), unit = unit, class = "measure")
}

unit_of <- function(x) {
  attr(x, "unit")
}

format.measure <- function(x, digits = 2, ...) {
  v <- as.numeric(x)
  if (length(v) == 0L) {
    return(character(0))
  }
  paste0(sprintf(paste0("%.", digits, "f"), v), " ", unit_of(x))
}

print.measure <- function(x, ...) {
  cat(sprintf("<measure [%d] %s>\n", length(x), unit_of(x)))
  lines <- format(x, ...)
  if (length(lines) > 0L) {
    cat(paste0(lines, "\n"), sep = "")
  }
  invisible(x)
}

summary.measure <- function(object, ...) {
  v <- as.numeric(object)
  keep <- v[!is.na(v)]
  has <- length(keep) > 0L
  structure(
    list(
      n = length(keep),
      mean = if (has) mean(keep) else NA_real_,
      min = if (has) min(keep) else NA_real_,
      max = if (has) max(keep) else NA_real_,
      unit = unit_of(object)
    ),
    class = "summary_measure"
  )
}

print.summary_measure <- function(x, ...) {
  cat(sprintf("measure summary (%s)\n", x$unit))
  cat(sprintf("  %-5s: %s\n", "n", format(x$n)))
  for (nm in c("mean", "min", "max")) {
    cat(sprintf("  %-5s: %s\n", nm, sprintf("%.2f", x[[nm]])))
  }
  invisible(x)
}

"+.measure" <- function(e1, e2) {
  left <- inherits(e1, "measure")
  right <- inherits(e2, "measure")
  if (left && right) {
    u1 <- unit_of(e1)
    u2 <- unit_of(e2)
    if (!identical(u1, u2)) {
      stop(sprintf("unit mismatch: %s vs %s", u1, u2), call. = FALSE)
    }
    return(measure(as.numeric(e1) + as.numeric(e2), u1))
  }
  if (left) {
    return(measure(as.numeric(e1) + as.numeric(e2), unit_of(e1)))
  }
  measure(as.numeric(e1) + as.numeric(e2), unit_of(e2))
}

"[.measure" <- function(x, i, ...) {
  measure(as.numeric(x)[i], unit_of(x))
}
