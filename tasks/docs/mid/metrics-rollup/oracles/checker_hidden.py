"""Core checks: the rollup table, region by region."""
import os
import sys


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def need(cond, msg):
    if not cond:
        fail(msg)


def read(path):
    need(os.path.isfile(path), "missing file: " + path)
    with open(path, encoding="utf-8") as fh:
        return fh.read().replace("\r\n", "\n").replace("\r", "\n")


def table_rows(text):
    rows = []
    for l in text.split("\n"):
        s = l.strip()
        if s.startswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if not all(c and set(c) <= set("-: ") for c in cells):
                rows.append(cells)
    return rows


doc = read("ROLLUP.md")
first = next((l.strip() for l in doc.split("\n") if l.strip()), "")
need(first == "# Global Pipeline Rollup 2026 Q1",
     "the file must open with '# Global Pipeline Rollup 2026 Q1', got " + repr(first))
need(any(l.strip() == "## By region" for l in doc.split("\n")),
     "missing heading: ## By region")

rows = table_rows(doc)
need(rows, "ROLLUP.md has no markdown table")
header = rows[0]
expect_header = ["Region", "Visits", "Signups", "Paid conversions",
                 "Bookings (EUR)", "Paid rate"]
need(header == expect_header,
     "the table header must be %r, got %r" % (expect_header, header))

body = rows[1:]
expect = [
    ["AMER", "509000", "18030", "2534", "2247300", "0.50%"],
    ["APAC", "283350", "8540", "1080", "886000", "0.38%"],
    ["EMEA", "370550", "11910", "1550", "1282600", "0.42%"],
    ["LATAM", "136300", "3490", "345", "255100", "0.25%"],
    ["All regions", "1299200", "41970", "5509", "4671000", "0.42%"],
]
need(len(body) == 5,
     "expected four region rows plus 'All regions', got %d rows" % len(body))
for got, want in zip(body, expect):
    need(len(got) == 6, "row must have 6 cells, got %r" % (got,))
    need(got[0] == want[0],
         "regions run alphabetically with 'All regions' last; expected %r, got %r"
         % (want[0], got[0]))
    for col, g, w in zip(expect_header, got, want):
        need(g == w, "%s: %s expected %r, got %r" % (want[0], col, w, g))

print("ok")
