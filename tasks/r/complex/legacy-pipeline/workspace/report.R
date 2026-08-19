# Stage 3 of the sales pipeline: weight each row by its region, then total.

# The commercial weighting agreed for each region.
REGION_WEIGHTS <- c(east = 1.2, north = 1.0, south = 1.1)

apply_weights <- function(df) {
  df$weighted <- df$revenue * REGION_WEIGHTS
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
