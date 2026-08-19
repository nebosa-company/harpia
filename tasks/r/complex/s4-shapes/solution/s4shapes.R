# An S4 shape hierarchy: virtual base, validity at construction, generics.

.positive_scalar <- function(v) {
  is.numeric(v) && length(v) == 1L && !is.na(v) && v > 0
}

.good_label <- function(v) {
  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
}

.check_factor <- function(k) {
  if (!.positive_scalar(k)) {
    stop("scale factor must be positive", call. = FALSE)
  }
  invisible(TRUE)
}

setClass("Shape", slots = c(name = "character"), contains = "VIRTUAL")

setValidity("Shape", function(object) {
  if (!.good_label(object@name)) {
    return("name must be a single non-empty string")
  }
  TRUE
})

setClass("Rect", contains = "Shape", slots = c(w = "numeric", h = "numeric"))

setValidity("Rect", function(object) {
  problems <- character(0)
  if (!.positive_scalar(object@w)) {
    problems <- c(problems, "width must be positive")
  }
  if (!.positive_scalar(object@h)) {
    problems <- c(problems, "height must be positive")
  }
  if (length(problems) > 0L) {
    return(problems)
  }
  TRUE
})

setClass("Circle", contains = "Shape", slots = c(r = "numeric"))

setValidity("Circle", function(object) {
  if (!.positive_scalar(object@r)) {
    return("radius must be positive")
  }
  TRUE
})

setClass("ShapeSet", slots = c(label = "character", shapes = "list"))

setValidity("ShapeSet", function(object) {
  if (!.good_label(object@label)) {
    return("label must be a single non-empty string")
  }
  if (length(object@shapes) > 0L &&
      !all(vapply(object@shapes, function(s) is(s, "Shape"), logical(1)))) {
    return("every element must be a Shape")
  }
  TRUE
})

setGeneric("area", function(shape, ...) standardGeneric("area"))
setGeneric("perimeter", function(shape, ...) standardGeneric("perimeter"))
setGeneric("scaled", function(shape, k, ...) standardGeneric("scaled"))

setMethod("area", "Rect", function(shape, ...) shape@w * shape@h)
setMethod("perimeter", "Rect", function(shape, ...) 2 * (shape@w + shape@h))
setMethod("scaled", "Rect", function(shape, k, ...) {
  .check_factor(k)
  new("Rect", name = shape@name, w = shape@w * k, h = shape@h * k)
})

setMethod("area", "Circle", function(shape, ...) pi * shape@r^2)
setMethod("perimeter", "Circle", function(shape, ...) 2 * pi * shape@r)
setMethod("scaled", "Circle", function(shape, k, ...) {
  .check_factor(k)
  new("Circle", name = shape@name, r = shape@r * k)
})

setMethod("area", "ShapeSet", function(shape, ...) {
  sum(vapply(shape@shapes, function(s) area(s), numeric(1)))
})
setMethod("perimeter", "ShapeSet", function(shape, ...) {
  sum(vapply(shape@shapes, function(s) perimeter(s), numeric(1)))
})
setMethod("scaled", "ShapeSet", function(shape, k, ...) {
  .check_factor(k)
  new(
    "ShapeSet",
    label = shape@label,
    shapes = lapply(shape@shapes, function(s) scaled(s, k))
  )
})

setMethod("show", "Rect", function(object) {
  cat(sprintf("Rect \"%s\" %g x %g\n", object@name, object@w, object@h))
  invisible(NULL)
})

setMethod("show", "Circle", function(object) {
  cat(sprintf("Circle \"%s\" r=%g\n", object@name, object@r))
  invisible(NULL)
})

setMethod("show", "ShapeSet", function(object) {
  cat(sprintf(
    "ShapeSet \"%s\" with %d shape(s), area %.3f\n",
    object@label, length(object@shapes), area(object)
  ))
  invisible(NULL)
})

rect <- function(name, w, h) {
  new("Rect", name = name, w = w, h = h)
}

circle <- function(name, r) {
  new("Circle", name = name, r = r)
}

shape_set <- function(label, shapes = list()) {
  new("ShapeSet", label = label, shapes = shapes)
}

total_area <- function(shapes) {
  if (!is.list(shapes)) {
    stop("every element must be a Shape", call. = FALSE)
  }
  if (length(shapes) == 0L) {
    return(0)
  }
  if (!all(vapply(shapes, function(s) is(s, "Shape"), logical(1)))) {
    stop("every element must be a Shape", call. = FALSE)
  }
  sum(vapply(shapes, function(s) area(s), numeric(1)))
}
