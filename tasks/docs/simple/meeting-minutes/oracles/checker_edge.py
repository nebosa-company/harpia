"""Edge checks for MINUTES.md: no absentees, real content, ISO dates only."""
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
    header = rows[0]
    body = [r for r in rows[1:]
            if not all(c and set(c) <= set("-: ") for c in r)]
    return header, body


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


doc = read("MINUTES.md")
low = doc.lower()

att = " | ".join(bullets_after(doc, "## Attendees")).lower()
for absent in ["rajesh iyer", "marco oliveira"]:
    need(absent not in att, "%s sent regrets and must not be listed as an attendee" % absent)
need(len(bullets_after(doc, "## Attendees")) == 6,
     "exactly the six people present belong in Attendees")

_, db = table_after(doc, "## Decisions")
dkeys = [("D1", "postgres 16"), ("D2", "canary"), ("D3", "redis"), ("D4", "sre")]
for (did, token), row in zip(dkeys, db):
    need(row[0] == did, "decision id order changed at " + did)
    need(token in row[1].lower(),
         "decision %s should carry the decision from the notes (missing %r): %r"
         % (did, token, row[1]))

_, ab = table_after(doc, "## Action Items")
akeys = [("A1", "runbook"), ("A2", "rehearsal"), ("A3", "canary"),
         ("A4", "capacity"), ("A5", "hiring plan")]
for (aid, token), row in zip(akeys, ab):
    need(aid == row[0], "action id order changed at " + aid)
    need(token in row[1].lower(),
         "action %s should carry the action from the notes (missing %r): %r"
         % (aid, token, row[1]))
for row in ab:
    need(re.fullmatch(r"\d{4}-\d{2}-\d{2}", row[3]),
         "Due column must hold an ISO date, got " + repr(row[3]))

# owners must be full names, never the raw scribe handles
for row in db + ab:
    need(row[2].strip().lower() not in
         {"pri", "dm", "hs", "ln", "tk", "ay", "rj", "mo"},
         "owner column must use full names from roster.csv, got " + repr(row[2]))

q = bullets_after(doc, "## Open Questions")
need(len(q) == 3, "expected 3 open questions, got %d" % len(q))
qjoined = " | ".join(q).lower()
for token in ["analytics replica", "canary", "h2"]:
    need(token in qjoined, "open questions are missing the one about %r" % token)

for bad in ["tbd", "fixme", "lorem ipsum", "todo:", "<placeholder>"]:
    need(bad not in low, "MINUTES.md still contains placeholder text: " + bad)

print("ok")
