"""Edge checks: duplicates excluded, columns balance, averages formatted."""
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


def table_rows(text):
    rows = []
    for l in text.split("\n"):
        s = l.strip()
        if s.startswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if not all(c and set(c) <= set("-: ") for c in cells):
                rows.append(cells)
    return rows


doc = read("q1-support.md")
rows = [r for r in table_rows(doc) if len(r) == 5 and r[0] != "Team"]
need(len(rows) == 5, "expected 5 data rows in the team table, got %d" % len(rows))

teams = {r[0]: r for r in rows}
need("All teams" in teams, "the table needs an 'All teams' row")
need(rows[-1][0] == "All teams", "the 'All teams' row must come last")

# tickets closed as duplicate never reach a count
need(teams["Billing"][1] != "12", "Billing's count includes a duplicate ticket")
need(teams["Search"][1] != "10", "Search's count includes a duplicate ticket")
need(teams["Mobile"][1] != "9", "Mobile's count includes a duplicate ticket")
need(teams["All teams"][1] != "39", "the totals include the three duplicate tickets")

# rows balance, and the totals row is the sum of the team rows
per_team = [r for r in rows if r[0] != "All teams"]
need(len(per_team) == 4, "expected exactly four teams, got %d" % len(per_team))
for r in per_team + [teams["All teams"]]:
    for idx, col in ((1, "Tickets"), (2, "Resolved"), (3, "Open")):
        need(re.fullmatch(r"\d+", r[idx]),
             "%s in row %s must be a plain integer, got %r" % (col, r[0], r[idx]))
    need(int(r[2]) + int(r[3]) == int(r[1]),
         "row %s: Resolved + Open must equal Tickets (%s + %s != %s)"
         % (r[0], r[2], r[3], r[1]))
for idx, col in ((1, "Tickets"), (2, "Resolved"), (3, "Open")):
    want = sum(int(r[idx]) for r in per_team)
    need(int(teams["All teams"][idx]) == want,
         "'All teams' %s is %s but the team rows sum to %d"
         % (col, teams["All teams"][idx], want))

for r in per_team + [teams["All teams"]]:
    need(re.fullmatch(r"\d+\.\d", r[4]),
         "Avg Resolution Hours must carry exactly one decimal place, got %r in row %s"
         % (r[4], r[0]))

# the overall average is over all resolved tickets, not an average of averages
need(teams["All teams"][4] != "17.5",
     "the 'All teams' average must be taken over every resolved ticket, "
     "not as the mean of the four team averages")

need(sorted(t[0] for t in per_team) == [t[0] for t in per_team],
     "team rows must be in alphabetical order")

for bad in ("tbd", "n/a", "fixme", "todo:"):
    need(bad not in doc.lower(), "the document still contains placeholder text: " + bad)

print("ok")
