import inspect

import library
from library import Book, add_book, find_by_author, titles, years_span

# every module-level function is fully annotated
functions = [add_book, find_by_author, titles, years_span]
for fn in functions:
    sig = inspect.signature(fn)
    for param in sig.parameters.values():
        assert param.annotation is not inspect.Parameter.empty, (
            f"{fn.__name__} parameter {param.name} lacks a type annotation"
        )
    assert sig.return_annotation is not inspect.Signature.empty, (
        f"{fn.__name__} lacks a return annotation"
    )

# behavior is preserved
b1 = Book("Dune", "Herbert", 1965)
b2 = Book("Emma", "Austen", 1815)
b3 = Book("Persuasion", "Austen", 1817)

catalog = []
assert add_book(catalog, b1) is catalog
add_book(catalog, Book("Dune", "Herbert", 1965))  # equal duplicate skipped
add_book(catalog, b2)
add_book(catalog, b3)
assert titles(catalog) == ["Dune", "Emma", "Persuasion"]
assert find_by_author(catalog, "Austen") == [b2, b3]
assert find_by_author(catalog, "herbert") == []  # exact match only
assert years_span(catalog) == (1815, 1965)
assert years_span([b1]) == (1965, 1965)

try:
    years_span([])
except ValueError:
    pass
else:
    raise AssertionError("years_span([]) should raise ValueError")

# the module keeps exactly its public surface
assert hasattr(library, "Member")

print("ok")
