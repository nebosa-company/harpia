source("s4shapes.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
msg <- function(expr) {
  tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
}
says <- function(expr, text) {
  m <- msg(expr)
  !is.na(m) && grepl(text, m, fixed = TRUE)
}

# --- a virtual class cannot be instantiated ----------------------------
check(!is.na(msg(new("Shape", name = "x"))),
      "a virtual class cannot be built directly")

# --- dimension validity --------------------------------------------------
check(says(new("Rect", name = "a", w = -1, h = 2), "width must be positive"),
      "a negative width is refused")
check(says(new("Rect", name = "a", w = 0, h = 2), "width must be positive"),
      "a zero width is refused")
check(says(new("Rect", name = "a", w = 1, h = 0), "height must be positive"),
      "a zero height is refused")
check(says(new("Rect", name = "a", w = 1, h = NA_real_),
           "height must be positive"),
      "an NA height is refused")
check(says(new("Rect", name = "a", w = c(1, 2), h = 3),
           "width must be positive"),
      "two widths are refused")
check(says(new("Circle", name = "a", r = -2), "radius must be positive"),
      "a negative radius is refused")
check(says(new("Circle", name = "a", r = 0), "radius must be positive"),
      "a zero radius is refused")
check(says(rect("a", -1, 2), "width must be positive"),
      "the convenience constructor validates too")
check(says(circle("a", -1), "radius must be positive"),
      "and so does the circle constructor")

# --- both dimensions wrong at once -------------------------------------
both <- msg(new("Rect", name = "a", w = -1, h = -2))
check(!is.na(both), "two bad dimensions still fail")
check(grepl("width must be positive", both, fixed = TRUE),
      "the width problem is reported")
check(grepl("height must be positive", both, fixed = TRUE),
      "and the height problem too")

# --- name validity, inherited from the virtual base --------------------
check(says(new("Rect", name = "", w = 1, h = 1),
           "name must be a single non-empty string"),
      "an empty name is refused")
check(says(new("Rect", name = c("a", "b"), w = 1, h = 1),
           "name must be a single non-empty string"),
      "two names are refused")
check(says(new("Rect", name = NA_character_, w = 1, h = 1),
           "name must be a single non-empty string"),
      "an NA name is refused")
check(says(new("Circle", name = "", r = 1),
           "name must be a single non-empty string"),
      "the rule is inherited by Circle as well")

# --- ShapeSet validity ---------------------------------------------------
b <- rect("box", 3, 4)
check(says(new("ShapeSet", label = "s", shapes = list(b, 5)),
           "every element must be a Shape"),
      "a number cannot join a shape set")
check(says(new("ShapeSet", label = "s", shapes = list("nope")),
           "every element must be a Shape"),
      "nor can a string")
check(says(new("ShapeSet", label = "", shapes = list()),
           "label must be a single non-empty string"),
      "an empty label is refused")
check(is.na(msg(new("ShapeSet", label = "s", shapes = list()))),
      "an empty set is valid")
check(is.na(msg(shape_set("s"))), "and the constructor defaults to empty")

# --- the scale factor ----------------------------------------------------
check(identical(msg(scaled(b, 0)), "scale factor must be positive"),
      "a zero factor is refused")
check(identical(msg(scaled(b, -2)), "scale factor must be positive"),
      "a negative factor is refused")
check(identical(msg(scaled(b, NA_real_)), "scale factor must be positive"),
      "an NA factor is refused")
check(identical(msg(scaled(b, c(2, 3))), "scale factor must be positive"),
      "two factors are refused")
check(identical(msg(scaled(b, "2")), "scale factor must be positive"),
      "a string factor is refused")
check(identical(msg(scaled(circle("c", 1), 0)),
                "scale factor must be positive"),
      "a Circle checks its factor too")
check(identical(msg(scaled(shape_set("s", list(b)), 0)),
                "scale factor must be positive"),
      "a ShapeSet checks its factor too")

# --- total_area rejects what it cannot measure ------------------------
check(identical(msg(total_area(list(b, 5))), "every element must be a Shape"),
      "a number in the list is refused")
check(identical(msg(total_area(list(b, "x"))),
                "every element must be a Shape"),
      "a string in the list is refused")
check(identical(msg(total_area(5)), "every element must be a Shape"),
      "a bare number is not a list of shapes")
check(identical(msg(total_area(b)), "every element must be a Shape"),
      "a single shape is not a list")

# --- a set may hold a mixture, and may nest by list -------------------
mixed <- shape_set("mix", list(rect("a", 1, 1), circle("b", 1),
                               rect("c", 2, 3)))
check(identical(length(mixed@shapes), 3L), "three members")
check(near(area(mixed), 1 + pi + 6), "the mixed total")
check(near(perimeter(mixed), 4 + 2 * pi + 10), "the mixed perimeter")
check(identical(capture.output(show(mixed)),
                sprintf("ShapeSet \"mix\" with 3 shape(s), area %.3f",
                        1 + pi + 6)),
      "the display line reports the live total")

# --- a one-member and a zero-member set display correctly -------------
check(identical(capture.output(show(shape_set("solo", list(b)))),
                "ShapeSet \"solo\" with 1 shape(s), area 12.000"),
      "a single-member set")
check(identical(capture.output(show(shape_set("empty"))),
                "ShapeSet \"empty\" with 0 shape(s), area 0.000"),
      "an empty set")

# --- validity is checked on every construction path -------------------
check(isTRUE(validObject(b, test = TRUE)), "a good object validates")
check(isTRUE(validObject(circle("c", 2), test = TRUE)),
      "a good circle validates")
check(isTRUE(validObject(shape_set("s", list(b)), test = TRUE)),
      "a good set validates")

# --- scaling composes ----------------------------------------------------
twice <- scaled(scaled(b, 2), 3)
check(near(twice@w, 18) && near(twice@h, 24), "two scalings compose")
check(near(area(twice), 432), "and the area follows")
check(near(b@w, 3), "the original survives both")

# --- generics really dispatch by class ---------------------------------
check(existsMethod("area", "Rect"), "there is an area method for Rect")
check(existsMethod("area", "Circle"), "and one for Circle")
check(existsMethod("area", "ShapeSet"), "and one for ShapeSet")
check(existsMethod("scaled", "Rect"), "there is a scaled method for Rect")
check(isGeneric("area"), "area is an S4 generic")
check(isGeneric("perimeter"), "perimeter is an S4 generic")
check(isGeneric("scaled"), "scaled is an S4 generic")

cat("ok\n")
