"""Core checks for q1-support.md."""
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


def lines_of(text):
    return [l.rstrip() for l in text.split("\n")]


def find_heading(ls, heading):
    for k, l in enumerate(ls):
        if l.strip() == heading:
            return k
    fail("missing heading: " + heading)


def table_after(text, heading):
    ls = lines_of(text)
    idx = find_heading(ls, heading)
    rows, started = [], False
    for l in ls[idx + 1:]:
        s = l.strip()
        if s.startswith("|"):
            started = True
            rows.append([c.strip() for c in s.strip("|").split("|")])
        elif started:
            break
        elif s.startswith("#"):
            break
    need(rows, "no markdown table under " + heading)
    body = [r for r in rows[1:] if not all(c and set(c) <= set("-: ") for c in r)]
    return rows[0], body


def bullets_after(text, heading):
    ls = lines_of(text)
    idx = find_heading(ls, heading)
    out, started = [], False
    for l in ls[idx + 1:]:
        s = l.strip()
        if s.startswith("- ") or s.startswith("* "):
            started = True
            out.append(s[2:].strip())
        elif s == "":
            continue
        elif started or s.startswith("#"):
            break
    return out


doc = read("q1-support.md")
ls = lines_of(doc)
first = next((l.strip() for l in ls if l.strip()), "")
need(first == "# Support Tickets 2026 Q1",
     "the file must open with '# Support Tickets 2026 Q1', got " + repr(first))

header, body = table_after(doc, "## By Team")
expect_header = ["Team", "Tickets", "Resolved", "Open", "Avg Resolution Hours"]
need(header == expect_header,
     "table header must be %r, got %r" % (expect_header, header))
expect = [
    ["Billing", "11", "8", "3", "14.8"],
    ["Mobile", "8", "5", "3", "27.0"],
    ["Platform", "8", "6", "2", "15.0"],
    ["Search", "9", "8", "1", "13.0"],
    ["All teams", "36", "27", "9", "16.6"],
]
need(len(body) == 5,
     "expected 4 team rows plus the 'All teams' row, got %d rows" % len(body))
for got, want in zip(body, expect):
    need(len(got) == 5, "row must have 5 cells: %r" % (got,))
    need(got[0] == want[0],
         "team rows must be alphabetical with 'All teams' last; expected %r, got %r"
         % (want[0], got[0]))
    for col, g, w in zip(expect_header, got, want):
        need(g == w, "%s: %s expected %r, got %r" % (want[0], col, w, g))

summary = bullets_after(doc, "## Summary")
expect_summary = [
    "Total tickets: 36",
    "Resolved tickets: 27",
    "Open tickets: 9",
    "Busiest team: Billing",
    "Slowest team by average resolution: Mobile",
]
need(summary == expect_summary,
     "Summary bullets wrong:\n  expected %r\n  got      %r" % (expect_summary, summary))

print("ok")
