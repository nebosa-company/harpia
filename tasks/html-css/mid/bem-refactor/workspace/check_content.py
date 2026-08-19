"""Captures the rendered copy of the teaser list.

Passes today. It must still pass after the class names change, because the
words on the page and the links they point at are not part of the refactor.

Run with: python check_content.py
"""

import sys
from html.parser import HTMLParser

EXPECTED_TEXT = [
    "The quiet cost of a stale cache",
    "Ilona Fekete - 6 min",
    "What a rollback actually restores",
    "Peter Aalto - 9 min",
    "Reading a flame graph without guessing",
    "Nadia Roche - 12 min",
    "Three questions before adding an index",
    "Sam Ibarra - 4 min",
]

EXPECTED_LINKS = [
    "/a/stale-cache",
    "/a/rollback",
    "/a/flame-graph",
    "/a/index-questions",
]

EXPECTED_IMAGES = [
    "img/cache.png",
    "img/rollback.png",
    "img/flame.png",
    "img/index.png",
]


class Reader(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self, convert_charrefs=True)
        self.text = []
        self.links = []
        self.images = []
        self.headings = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and attrs.get("href"):
            self.links.append(attrs["href"])
        if tag == "img":
            self.images.append(attrs.get("src"))
        if tag == "h3":
            self.headings += 1

    def handle_data(self, data):
        self.text.append(data)


def main():
    with open("index.html", "r", encoding="utf-8") as handle:
        reader = Reader()
        reader.feed(handle.read())
        reader.close()

    page = " ".join("".join(reader.text).split())
    problems = []

    for phrase in EXPECTED_TEXT:
        if phrase not in page:
            problems.append("missing copy: %r" % phrase)

    if reader.links != EXPECTED_LINKS:
        problems.append("links changed: %r" % (reader.links,))
    if reader.images != EXPECTED_IMAGES:
        problems.append("images changed: %r" % (reader.images,))
    if reader.headings != 4:
        problems.append("expected four <h3> teaser titles, found %d" % reader.headings)

    if problems:
        for problem in problems:
            print("FAIL:", problem)
        sys.exit(1)
    print("content preserved")


if __name__ == "__main__":
    main()
