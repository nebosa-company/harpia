# Stage 3 of the sales pipeline: weight each row by its region, then total.

# The commercial weighting agreed for each region.
REGION_WEIGHTS <- c(east = 1.2, north = 1.0, south = 1.1)

# Each row is weighted by the entry named after its own region. Multiplying
# by the whole weight vector recycled it down the rows instead, which is
# silent whenever the row count is a multiple of the number of regions.
apply_weights <- function(df) {
  df$weighted <- df$revenue * unname(REGION_WEIGHTS[as.character(df$region)])
  df
}

total_report <- function(df) {
  df <- apply_weights(df)
  data.frame(
    rows = nrow(df),
    revenue = sum(df$revenue, na.rm = TRUE),
    weighted = sum(df$weighted, na.rm = TRUE),
    row.names = NULL
  )
}

region_report <- function(df) {
  df <- apply_weights(df)
  region <- as.character(df$region)
  known <- !is.na(region)
  present <- sort(unique(region[known]))

  if (length(present) == 0L) {
    return(data.frame(
      region = character(0),
      rows = integer(0),
      qty = numeric(0),
      revenue = numeric(0),
      weighted = numeric(0),
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  totals <- function(column) {
    vapply(
      present,
      function(g) sum(df[[column]][known & region == g], na.rm = TRUE),
      numeric(1),
      USE.NAMES = FALSE
    )
  }

  data.frame(
    region = present,
    rows = vapply(
      present,
      function(g) sum(known & region == g),
      integer(1),
      USE.NAMES = FALSE
    ),
    qty = totals("qty"),
    revenue = totals("revenue"),
    weighted = totals("weighted"),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}
