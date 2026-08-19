"""Edge checks: the metric is named, and nothing consistent is flagged."""
import os
import re
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


doc = read("discrepancies.md")
rows = []
for l in doc.split("\n"):
    s = l.strip()
    if s.startswith("|"):
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not all(c and set(c) <= set("-: ") for c in cells):
            rows.append(cells)
need(len(rows) >= 2, "discrepancies.md has no data rows")
body = [r for r in rows[1:] if len(r) == 3]
need(len(body) == 3, "expected exactly 3 discrepancy rows, got %d" % len(body))

# each row names the metric and the period it disagrees about
wants = [
    (["availability"], ["q2", "quarter 2"]),
    (["enterprise account", "active enterprise", "accounts"], ["q3", "quarter 3"]),
    (["headcount"], ["2025", "year"]),
]
for i, (row, (metric_alts, period_alts)) in enumerate(zip(body, wants)):
    cell = row[0].lower()
    need(any(a in cell for a in metric_alts),
         "row %d must name the metric (one of %r), got %r" % (i + 1, metric_alts, row[0]))
    need(any(a in cell for a in period_alts),
         "row %d must name the period in dispute (one of %r), got %r"
         % (i + 1, period_alts, row[0]))

# report cells name real files, no paths, two per row, in file order
for row in body:
    names = [n.strip() for n in row[1].split(",")]
    need(len(names) == 2, "each disagreement here involves two reports, got %r" % row[1])
    for n in names:
        need(re.fullmatch(r"20\d\d-Q\d\.md", n),
             "report cells hold bare file names like 2025-Q4.md, got %r" % n)
        need(os.path.isfile(os.path.join("reports", n)), "no such report: %r" % n)
    need(names == sorted(names), "report names must be listed oldest first: %r" % row[1])
    need(len([v for v in row[2].split(",")]) == 2,
         "each row needs one value per report: %r" % row[2])

# figures that agree across the pack must not be flagged
low = doc.lower()
for clean in ["retention", "support ticket", "partner channel"]:
    need(clean not in low,
         "the pack is consistent about %r, so it must not appear as a "
         "disagreement" % clean)
for word in ["arr", "nps"]:
    need(not re.search(r"\b%s\b" % word, low),
         "the pack is consistent about %s, so it must not appear as a "
         "disagreement" % word.upper())
for figure in ["1204", "1318", "1290", "1402", "1357", "108%", "110%",
               "111%", "113%", "112%", "18.4", "19.2", "20.1", "21.6", "22.9"]:
    need(figure not in doc,
         "%s is reported consistently across the pack and must not be flagged"
         % figure)

print("ok")
