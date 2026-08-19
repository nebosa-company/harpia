# Stage 1 of the sales pipeline: read the raw extract off disk.

load_sales <- function(path = "data/sales.csv") {
  read.csv(path, stringsAsFactors = TRUE)
}
