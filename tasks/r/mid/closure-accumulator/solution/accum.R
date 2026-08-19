# Closure-based stateful modules. All state lives in the factory frame.

make_accumulator <- function(start = 0) {
  origin <- as.numeric(start)
  running <- origin
  seen <- numeric(0)

  add <- function(x) {
    if (!is.numeric(x)) {
      stop("add expects a numeric value", call. = FALSE)
    }
    running <<- running + sum(x)
    seen <<- c(seen, as.numeric(x))
    invisible(running)
  }

  list(
    add = add,
    total = function() running,
    count = function() length(seen),
    history = function() seen,
    reset = function() {
      running <<- origin
      seen <<- numeric(0)
      invisible(NULL)
    }
  )
}

make_tally <- function() {
  tab <- integer(0)

  hit <- function(label) {
    if (!is.character(label) || length(label) != 1L || is.na(label)) {
      stop("hit expects a single label", call. = FALSE)
    }
    current <- if (label %in% names(tab)) tab[[label]] else 0L
    tab[[label]] <<- current + 1L
    invisible(current + 1L)
  }

  list(
    hit = hit,
    counts = function() {
      if (length(tab) == 0L) {
        return(tab)
      }
      tab[order(names(tab))]
    },
    top = function(n) {
      if (length(tab) == 0L || n <= 0) {
        return(character(0))
      }
      labels <- names(tab)
      labels[order(-as.integer(tab), labels)][seq_len(min(n, length(tab)))]
    }
  )
}

make_limited <- function(cap) {
  ceiling_v <- as.numeric(cap)
  running <- 0
  refused <- 0L

  add <- function(x) {
    if (!is.numeric(x) || length(x) != 1L) {
      stop("add expects a single number", call. = FALSE)
    }
    if (running + x > ceiling_v) {
      refused <<- refused + 1L
      stop(sprintf("cap %g exceeded", ceiling_v), call. = FALSE)
    }
    running <<- running + x
    invisible(running)
  }

  list(
    add = add,
    total = function() running,
    rejected = function() refused
  )
}
