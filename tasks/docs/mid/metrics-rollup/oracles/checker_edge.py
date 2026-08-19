"""Edge checks: the two traps, the closure of every column, the highlights."""
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


doc = read("ROLLUP.md")
rows = []
for l in doc.split("\n"):
    s = l.strip()
    if s.startswith("|"):
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not all(c and set(c) <= set("-: ") for c in cells):
            rows.append(cells)
need(len(rows) >= 2, "ROLLUP.md has no data rows")
body = [r for r in rows[1:] if len(r) == 6]
need(len(body) == 5, "expected 5 data rows, got %d" % len(body))
by_region = {r[0]: r for r in body}

# trap 1: the EMEA table prints its own total row, which is not a market
need("EMEA" in by_region, "no EMEA row")
need(by_region["EMEA"][1] != "741100",
     "EMEA visits double-count the region's own Total row")
need(by_region["EMEA"][3] != "3100",
     "EMEA paid conversions double-count the region's own Total row")

# trap 2: APAC reports bookings in thousands of euro
need("APAC" in by_region, "no APAC row")
need(by_region["APAC"][4] != "886",
     "APAC bookings are reported in thousands of euro and must be converted")
need(by_region["APAC"][4] != "886.0",
     "APAC bookings are reported in thousands of euro and must be converted")

# every column closes
regions = [r for r in body if r[0] != "All regions"]
total = by_region.get("All regions")
need(total is not None, "the table needs an 'All regions' row")
for idx, col in ((1, "Visits"), (2, "Signups"), (3, "Paid conversions"),
                 (4, "Bookings (EUR)")):
    for r in body:
        need(re.fullmatch(r"\d+", r[idx]),
             "%s in row %s must be a whole number with no separators, got %r"
             % (col, r[0], r[idx]))
    want = sum(int(r[idx]) for r in regions)
    need(int(total[idx]) == want,
         "'All regions' %s is %s but the region rows sum to %d"
         % (col, total[idx], want))

# rates are derived from the counts, not averaged
for r in body:
    need(re.fullmatch(r"\d+\.\d\d%", r[5]),
         "Paid rate must be a percentage with two decimals, got %r in row %s"
         % (r[5], r[0]))
    want = round(int(r[3]) / int(r[1]) * 100, 2)
    got = float(r[5].rstrip("%"))
    need(abs(got - want) < 0.005,
         "%s paid rate should be %.2f%%, got %s" % (r[0], want, r[5]))
need(total[5] != "0.39%",
     "the overall paid rate must come from the totals, not from averaging the "
     "four regional rates")

# highlights
low = doc.lower()
need("united states" in low,
     "the largest market by bookings is the United States and must be named")
need("amer" in low, "the largest market's region must be named")
m = re.search(r"markets counted:\s*(\d+)", low)
need(m, "the highlights must state 'Markets counted: <n>'")
need(m.group(1) == "10",
     "ten markets are reported across the four regions, got %s" % m.group(1))
m2 = re.search(r"markets with no paid conversions:\s*(\d+)", low)
need(m2, "the highlights must state 'Markets with no paid conversions: <n>'")
need(m2.group(1) == "1",
     "one market has no paid conversions, got %s" % m2.group(1))
need("total" not in [r[0].lower() for r in body],
     "'Total' is a row inside the EMEA source table, not a region")

print("ok")
