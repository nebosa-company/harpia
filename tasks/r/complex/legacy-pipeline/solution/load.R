# Stage 1 of the sales pipeline: read the raw extract off disk.
#
# Text columns stay character. Reading them as factors made the region
# fix-up below assign a level that did not exist, which silently produced
# NA instead of the corrected label.

load_sales <- function(path = "data/sales.csv") {
  read.csv(path, stringsAsFactors = FALSE)
}
