# The sales pipeline, end to end.
source("load.R")
source("transform.R")
source("report.R")

run_pipeline <- function(path = "data/sales.csv") {
  total_report(prepare(load_sales(path)))
}
