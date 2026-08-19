# Function factories for the rule engine.
#
# Each factory takes its settings and returns a function that applies them.
# The build_* helpers turn a vector of settings into a list of ready-made
# functions, one per element and in the same order.

make_adder <- function(n) {
  function(x) x + n
}

make_scaler <- function(k) {
  function(x) x * k
}

make_prefixer <- function(prefix) {
  function(x) paste0(prefix, x)
}

make_clamp <- function(lo, hi) {
  function(x) pmin(pmax(x, lo), hi)
}

build_adders <- function(ns) {
  out <- vector("list", length(ns))
  for (i in seq_along(ns)) {
    out[[i]] <- make_adder(ns[[i]])
  }
  out
}

build_scalers <- function(ks) {
  out <- vector("list", length(ks))
  for (i in seq_along(ks)) {
    out[[i]] <- make_scaler(ks[[i]])
  }
  out
}

build_prefixers <- function(prefixes) {
  out <- vector("list", length(prefixes))
  for (i in seq_along(prefixes)) {
    out[[i]] <- make_prefixer(prefixes[[i]])
  }
  out
}

build_clamps <- function(los, his) {
  out <- vector("list", length(los))
  for (i in seq_along(los)) {
    out[[i]] <- make_clamp(los[[i]], his[[i]])
  }
  out
}
