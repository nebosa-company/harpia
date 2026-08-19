# Calendar helpers for the billing run. Locale-independent throughout:
# the weekday comes from POSIXlt$wday, never from weekdays().

month_end <- function(d) {
  if (length(d) == 0L) {
    return(d)
  }
  lt <- as.POSIXlt(d)
  lt$mday <- 1L
  lt$mon <- lt$mon + 1L
  as.Date(lt) - 1
}

month_bucket <- function(d) {
  format(d, "%Y-%m")
}

add_months <- function(d, n) {
  if (length(d) == 0L) {
    return(d)
  }
  lt <- as.POSIXlt(d)
  day <- lt$mday
  lt$mday <- 1L
  lt$mon <- lt$mon + n
  first <- as.Date(lt)
  last_day <- as.integer(format(month_end(first), "%d"))
  first + (pmin(day, last_day) - 1L)
}

business_days <- function(from, to) {
  n <- max(length(from), length(to))
  if (n == 0L) {
    return(integer(0))
  }
  from <- rep(from, length.out = n)
  to <- rep(to, length.out = n)
  vapply(seq_len(n), function(i) {
    a <- from[i]
    b <- to[i]
    if (is.na(a) || is.na(b)) {
      return(NA_integer_)
    }
    if (b < a) {
      return(0L)
    }
    days <- seq(a, b, by = "day")
    sum(as.POSIXlt(days)$wday %in% 1:5)
  }, integer(1))
}
