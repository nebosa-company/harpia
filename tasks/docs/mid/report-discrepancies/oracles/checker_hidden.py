"""Core checks: exactly the three real disagreements, correctly attributed."""
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


def table(text):
    rows = []
    for l in text.split("\n"):
        s = l.strip()
        if s.startswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            rows.append(cells)
    need(rows, "no markdown table in discrepancies.md")
    header = rows[0]
    body = [r for r in rows[1:] if not all(c and set(c) <= set("-: ") for c in r)]
    return header, body


doc = read("discrepancies.md")
first = next((l.strip() for l in doc.split("\n") if l.strip()), "")
need(first == "# Reported Discrepancies",
     "the file must open with '# Reported Discrepancies', got " + repr(first))

header, body = table(doc)
need(header == ["Metric", "Reports", "Values"],
     "the table header must be | Metric | Reports | Values |, got %r" % (header,))

need(len(body) == 3,
     "there are exactly three disagreements in the pack; the table has %d rows:\n%s"
     % (len(body), "\n".join(" | ".join(r) for r in body)))

expect = [
    ("2025-Q2.md, 2025-Q4.md", "99.95%, 99.87%"),
    ("2025-Q3.md, 2025-Q4.md", "412, 418"),
    ("2025-Q4.md, 2026-Q1.md", "96, 91"),
]
for i, (row, (reports, values)) in enumerate(zip(body, expect)):
    need(len(row) == 3, "row %d must have 3 cells, got %r" % (i + 1, row))
    need(row[1] == reports,
         "row %d: Reports must be %r (earliest report first, rows ordered by that "
         "report), got %r" % (i + 1, reports, row[1]))
    need(row[2] == values,
         "row %d: Values must be %r, in the same order as the reports, exactly as "
         "printed in the source, got %r" % (i + 1, values, row[2]))

print("ok")
