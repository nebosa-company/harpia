# Stage 2 of the sales pipeline: tidy the region labels, turn the recorded
# quantity into a number, and derive revenue.

# Spellings the source system has been known to emit, and what they mean.
REGION_FIXUPS <- c(eastern = "east", nrth = "north")

normalise_regions <- function(df) {
  region <- as.character(df$region)
  for (bad in names(REGION_FIXUPS)) {
    hit <- !is.na(region) & region == bad
    region[hit] <- REGION_FIXUPS[[bad]]
  }
  df$region <- region
  df
}

# The quantity arrives as text because the warehouse writes "-" when it
# reported nothing. Going through as.character first matters: applied
# straight to a factor, as.integer would hand back the level codes rather
# than the recorded amounts, and as.integer would drop the half units.
parse_qty <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

prepare <- function(df) {
  df <- normalise_regions(df)
  df$qty <- parse_qty(df$qty)
  df$revenue <- df$qty * df$price
  df
}
