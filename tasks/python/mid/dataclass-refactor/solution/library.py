"""A tiny lending-library model."""

from dataclasses import dataclass


@dataclass
class Book:
    title: str
    author: str
    year: int


@dataclass
class Member:
    name: str
    member_id: int


def add_book(catalog: list[Book], book: Book) -> list[Book]:
    """Append `book` unless an equal book is already present; return the catalog."""
    if book not in catalog:
        catalog.append(book)
    return catalog


def find_by_author(catalog: list[Book], author: str) -> list[Book]:
    """All books whose author matches exactly, in catalog order."""
    return [b for b in catalog if b.author == author]


def titles(catalog: list[Book]) -> list[str]:
    """The titles of the catalog, in order."""
    return [b.title for b in catalog]


def years_span(catalog: list[Book]) -> tuple[int, int]:
    """(earliest, latest) publication year; ValueError on an empty catalog."""
    if not catalog:
        raise ValueError("empty catalog")
    years = [b.year for b in catalog]
    return (min(years), max(years))
