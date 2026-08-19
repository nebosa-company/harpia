source("s4shapes.R")

fail <- function(m) { cat("FAIL:", m, "\n"); quit(status = 1) }
check <- function(cond, m) if (!isTRUE(cond)) fail(m)
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# --- the class hierarchy ------------------------------------------------
check(isVirtualClass("Shape"), "Shape must be a virtual class")
check(isVirtualClass("Rect") == FALSE, "Rect is concrete")
check(extends("Rect", "Shape"), "Rect extends Shape")
check(extends("Circle", "Shape"), "Circle extends Shape")
check("name" %in% slotNames("Rect"), "Rect inherits the name slot")
check(all(c("w", "h") %in% slotNames("Rect")), "Rect's own slots")
check("r" %in% slotNames("Circle"), "Circle's own slot")
check(all(c("label", "shapes") %in% slotNames("ShapeSet")),
      "ShapeSet's slots")

# --- constructing --------------------------------------------------------
b <- rect("box", 3, 4)
check(isVirtualClass("Shape"), "Shape stays virtual")
check(is(b, "Rect"), "rect() builds a Rect")
check(is(b, "Shape"), "a Rect is a Shape")
check(isVirtualClass("Shape"), "still virtual after construction")
check(identical(b@name, "box"), "the name slot")
check(near(b@w, 3) && near(b@h, 4), "the dimension slots")
check(isTRUE(validObject(b, test = TRUE)), "a good rectangle validates")

g <- circle("ring", 3)
check(is(g, "Circle"), "circle() builds a Circle")
check(is(g, "Shape"), "a Circle is a Shape")
check(near(g@r, 3), "the radius slot")

s <- shape_set("set", list(b, g))
check(is(s, "ShapeSet"), "shape_set() builds a ShapeSet")
check(identical(s@label, "set"), "the label slot")
check(identical(length(s@shapes), 2L), "both shapes are held")

# --- area and perimeter --------------------------------------------------
check(near(area(b), 12), "the rectangle's area")
check(near(perimeter(b), 14), "the rectangle's perimeter")
check(near(area(g), pi * 9), "the circle's area")
check(near(perimeter(g), 2 * pi * 3), "the circle's circumference")
check(near(area(s), 12 + pi * 9), "the set totals its members' areas")
check(near(perimeter(s), 14 + 2 * pi * 3), "and their perimeters")
check(near(area(shape_set("none")), 0), "an empty set has no area")
check(near(perimeter(shape_set("none")), 0), "and no perimeter")

# --- scaled --------------------------------------------------------------
b2 <- scaled(b, 2)
check(is(b2, "Rect"), "scaling a Rect gives a Rect")
check(near(b2@w, 6) && near(b2@h, 8), "both dimensions are scaled")
check(identical(b2@name, "box"), "the name is carried over")
check(near(area(b2), 48), "the area grows with the square of the factor")
check(near(b@w, 3), "the original is left untouched")

g2 <- scaled(g, 2)
check(is(g2, "Circle"), "scaling a Circle gives a Circle")
check(near(g2@r, 6), "the radius is scaled")
check(near(g@r, 3), "the original circle is untouched")

s2 <- scaled(s, 2)
check(is(s2, "ShapeSet"), "scaling a set gives a set")
check(identical(s2@label, "set"), "the label is carried over")
check(identical(length(s2@shapes), 2L), "every member survives")
check(near(area(s2), 4 * (12 + pi * 9)), "every member was scaled")
check(near(area(s), 12 + pi * 9), "the original set is untouched")

half <- scaled(b, 0.5)
check(near(half@w, 1.5) && near(half@h, 2), "a fractional factor")

# --- show ----------------------------------------------------------------
check(identical(capture.output(show(b)), "Rect \"box\" 3 x 4"),
      "the rectangle's display line")
check(identical(capture.output(show(g)), "Circle \"ring\" r=3"),
      "the circle's display line")
check(identical(capture.output(show(s)),
                "ShapeSet \"set\" with 2 shape(s), area 40.274"),
      "the set's display line")
check(identical(capture.output(print(b)), "Rect \"box\" 3 x 4"),
      "printing goes through show")
check(identical(capture.output(show(rect("odd", 2.5, 4))),
                "Rect \"odd\" 2.5 x 4"),
      "a fractional measurement keeps its decimal")
check(is.null(withVisible(show(b))$value), "show returns NULL")
check(identical(withVisible(show(b))$visible, FALSE),
      "and returns it invisibly")

# --- total_area ----------------------------------------------------------
check(near(total_area(list(b, g)), 12 + pi * 9), "a plain list of shapes")
check(near(total_area(list()), 0), "an empty list has no area")
check(near(total_area(list(b)), 12), "a single shape")
check(is.double(total_area(list(b, g))), "total_area returns a double")

cat("ok\n")
