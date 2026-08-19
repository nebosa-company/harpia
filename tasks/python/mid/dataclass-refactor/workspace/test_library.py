"""Behavior checks for library.py. Run: python test_library.py"""

from library import Book, Member, add_book, find_by_author, titles, years_span

b1 = Book("Dune", "Herbert", 1965)
b2 = Book("Dune", "Herbert", 1965)
b3 = Book("Emma", "Austen", 1815)

assert b1 == b2
assert b1 != b3
assert repr(b1) == "Book(title='Dune', author='Herbert', year=1965)"

m = Member("Ada", 7)
assert m == Member("Ada", 7)
assert repr(m) == "Member(name='Ada', member_id=7)"

catalog = []
add_book(catalog, b1)
add_book(catalog, b2)  # duplicate: not added
add_book(catalog, b3)
assert titles(catalog) == ["Dune", "Emma"]
assert find_by_author(catalog, "Austen") == [b3]
assert find_by_author(catalog, "Nobody") == []
assert years_span(catalog) == (1815, 1965)

try:
    years_span([])
except ValueError:
    pass
else:
    raise AssertionError("years_span([]) should raise ValueError")

print("all checks passed")
