import dataclasses
import typing

from library import Book, Member

# both classes must be dataclasses
assert dataclasses.is_dataclass(Book), "Book must be a dataclass"
assert dataclasses.is_dataclass(Member), "Member must be a dataclass"

# field names, order, and annotations
book_fields = dataclasses.fields(Book)
assert [f.name for f in book_fields] == ["title", "author", "year"]
assert typing.get_type_hints(Book) == {"title": str, "author": str, "year": int}

member_fields = dataclasses.fields(Member)
assert [f.name for f in member_fields] == ["name", "member_id"]
assert typing.get_type_hints(Member) == {"name": str, "member_id": int}

# generated behavior matches the frozen contract
b = Book("Dune", "Herbert", 1965)
assert b == Book("Dune", "Herbert", 1965)
assert b != Book("Dune", "Herbert", 1966)
assert repr(b) == "Book(title='Dune', author='Herbert', year=1965)"
assert b.title == "Dune" and b.author == "Herbert" and b.year == 1965

m = Member("Ada", 7)
assert m == Member("Ada", 7)
assert m != Member("Ada", 8)
assert repr(m) == "Member(name='Ada', member_id=7)"

# construction by keyword works (a dataclass given the right field order)
assert Book(title="Emma", author="Austen", year=1815) == Book("Emma", "Austen", 1815)

print("ok")
