"""Core checks for totals.csv: every invoice, every figure."""
import csv
import os
import sys


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def need(cond, msg):
    if not cond:
        fail(msg)


need(os.path.isfile("totals.csv"), "missing file: totals.csv")
with open("totals.csv", encoding="utf-8", newline="") as fh:
    rows = [r for r in csv.reader(fh) if any(c.strip() for c in r)]

need(rows, "totals.csv is empty")
header = [c.strip() for c in rows[0]]
expect_header = ["invoice_id", "client", "line_items", "subtotal",
                 "discount", "tax", "total"]
need(header == expect_header,
     "header must be %s, got %s" % (",".join(expect_header), ",".join(header)))

body = [[c.strip() for c in r] for r in rows[1:]]
expect = [
    ["INV-2041", "Northwind Analytics", "3", "8100.00", "405.00", "1615.95", "9310.95"],
    ["INV-2042", "Halden Marine", "2", "2920.00", "0.00", "730.00", "3650.00"],
    ["INV-2043", "Castellane Foods", "3", "3274.00", "327.40", "589.32", "3535.92"],
    ["INV-2044", "Northwind Analytics", "2", "6400.00", "800.00", "1176.00", "6776.00"],
    ["INV-2045", "Ptarmigan Rail", "4", "7478.00", "0.00", "1869.50", "9347.50"],
    ["TOTAL", "", "14", "28172.00", "1532.40", "5980.77", "32620.37"],
]
need(len(body) == len(expect),
     "expected %d data rows (5 invoices + TOTAL), got %d" % (len(expect), len(body)))
for got, want in zip(body, expect):
    need(len(got) == 7, "row must have 7 fields, got %d: %r" % (len(got), got))
    need(got[0] == want[0],
         "rows must be sorted by invoice_id with TOTAL last; expected %s, got %s"
         % (want[0], got[0]))
    for col, g, w in zip(expect_header, got, want):
        need(g == w, "%s: column %s expected %r, got %r" % (want[0], col, w, g))

print("ok")
