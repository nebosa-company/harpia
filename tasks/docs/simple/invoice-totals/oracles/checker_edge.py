"""Edge checks: voided lines excluded, formatting clean, totals self-consistent."""
import csv
import os
import re
import sys


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def need(cond, msg):
    if not cond:
        fail(msg)


need(os.path.isfile("totals.csv"), "missing file: totals.csv")
with open("totals.csv", encoding="utf-8", newline="") as fh:
    rows = [[c.strip() for c in r] for r in csv.reader(fh) if any(c.strip() for c in r)]
need(len(rows) >= 2, "totals.csv has no data rows")
body = rows[1:]
by_id = {r[0]: r for r in body if len(r) == 7}

need("INV-2043" in by_id and "INV-2045" in by_id, "missing invoice rows")

# the voided line items must never reach a total
need(by_id["INV-2043"][3] != "4274.00",
     "INV-2043 subtotal includes the cancelled onsite audit line")
need(by_id["INV-2045"][3] != "8378.00",
     "INV-2045 subtotal includes the voided February retainer line")
need(by_id["INV-2043"][2] != "4", "INV-2043 line_items counts the voided line")
need(by_id["INV-2045"][2] != "5", "INV-2045 line_items counts the voided line")

money = re.compile(r"-?\d+\.\d{2}$")
for r in body:
    need(len(r) == 7, "row must have 7 fields: %r" % (r,))
    need(re.fullmatch(r"\d+", r[2]), "line_items must be a plain integer: %r" % r[2])
    for col, val in zip(("subtotal", "discount", "tax", "total"), r[3:7]):
        need(money.fullmatch(val),
             "%s in row %s must be a plain number with exactly 2 decimals, got %r"
             % (col, r[0], val))
        need("," not in val and "€" not in val and "EUR" not in val,
             "%s in row %s must carry no currency symbol or separator: %r"
             % (col, r[0], val))

# per-row arithmetic: total = subtotal - discount + tax
for r in body:
    sub, disc, tax, tot = (round(float(x) * 100) for x in r[3:7])
    need(sub - disc + tax == tot,
         "row %s does not balance: %s - %s + %s != %s" % (r[0], r[3], r[4], r[5], r[6]))

# the TOTAL row must be the column-wise sum of the invoice rows
need(body[-1][0] == "TOTAL", "the last row must have invoice_id TOTAL")
need(body[-1][1] == "", "the TOTAL row must leave the client column empty")
inv = [r for r in body if r[0] != "TOTAL"]
need(int(body[-1][2]) == sum(int(r[2]) for r in inv),
     "TOTAL line_items is not the sum of the invoice rows")
for idx, col in ((3, "subtotal"), (4, "discount"), (5, "tax"), (6, "total")):
    want = sum(round(float(r[idx]) * 100) for r in inv)
    got = round(float(body[-1][idx]) * 100)
    need(want == got,
         "TOTAL %s is %s but the invoice rows sum to %.2f" % (col, body[-1][idx], want / 100.0))

print("ok")
