"""A tiny lending-library model."""


class Book:
    def __init__(self, title, author, year):
        self.title = title
        self.author = author
        self.year = year

    def __repr__(self):
        return "Book(title={!r}, author={!r}, year={!r})".format(
            self.title, self.author, self.year
        )

    def __eq__(self, other):
        if other.__class__ is not Book:
            return NotImplemented
        return (self.title, self.author, self.year) == (
            other.title,
            other.author,
            other.year,
        )


class Member:
    def __init__(self, name, member_id):
        self.name = name
        self.member_id = member_id

    def __repr__(self):
        return "Member(name={!r}, member_id={!r})".format(self.name, self.member_id)

    def __eq__(self, other):
        if other.__class__ is not Member:
            return NotImplemented
        return (self.name, self.member_id) == (other.name, other.member_id)


def add_book(catalog, book):
    """Append `book` unless an equal book is already present; return the catalog."""
    if book not in catalog:
        catalog.append(book)
    return catalog


def find_by_author(catalog, author):
    """All books whose author matches exactly, in catalog order."""
    return [b for b in catalog if b.author == author]


def titles(catalog):
    """The titles of the catalog, in order."""
    return [b.title for b in catalog]


def years_span(catalog):
    """(earliest, latest) publication year; ValueError on an empty catalog."""
    if not catalog:
        raise ValueError("empty catalog")
    years = [b.year for b in catalog]
    return (min(years), max(years))
