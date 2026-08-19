# Stage 2 of the sales pipeline: tidy the region labels, turn the recorded
# quantity into a number, and derive revenue.

# Spellings the source system has been known to emit, and what they mean.
REGION_FIXUPS <- c(eastern = "east", nrth = "north")

normalise_regions <- function(df) {
  for (bad in names(REGION_FIXUPS)) {
    df$region[df$region == bad] <- REGION_FIXUPS[[bad]]
  }
  df
}

parse_qty <- function(x) {
  as.integer(x)
}

prepare <- function(df) {
  df <- normalise_regions(df)
  df$qty <- parse_qty(df$qty)
  df$revenue <- df$qty * df$price
  df
}
