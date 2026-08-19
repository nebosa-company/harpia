"""Core checks for MINUTES.md."""
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
ls = lines_of(doc)

first = next((l for l in ls if l.strip()), "")
need(first.strip() == "# Platform Sync 2026-03-04",
     "first heading must be '# Platform Sync 2026-03-04', got: " + repr(first))

order = ["## Attendees", "## Decisions", "## Action Items", "## Open Questions"]
positions = [find_heading(ls, h) for h in order]
need(positions == sorted(positions), "sections are out of order: " + str(order))

att = bullets_after(doc, "## Attendees")
expect_att = [
    "Priya Raman (Engineering Manager)",
    "Dmitri Sokolov (Staff Engineer)",
    "Hannah Steiner (Platform Lead)",
    "Lena Okoro (Build Engineer)",
    "Takeshi Mori (Site Reliability Engineer)",
    "Ayo Adeyemi (Director of Engineering)",
]
need(att == expect_att,
     "Attendees must be exactly these bullets in roster order:\n  expected %r\n  got      %r"
     % (expect_att, att))

dh, db = table_after(doc, "## Decisions")
need(dh == ["ID", "Decision", "Owner"],
     "Decisions header must be | ID | Decision | Owner |, got " + str(dh))
need(len(db) == 4, "expected 4 decision rows, got %d" % len(db))
need([r[0] for r in db] == ["D1", "D2", "D3", "D4"],
     "decision ids must be D1..D4 in order, got " + str([r[0] for r in db]))
expect_downers = ["Dmitri Sokolov", "Hannah Steiner", "Takeshi Mori", "Ayo Adeyemi"]
got_downers = [r[2] for r in db]
need(got_downers == expect_downers,
     "decision owners wrong:\n  expected %r\n  got      %r" % (expect_downers, got_downers))

ah, ab = table_after(doc, "## Action Items")
need(ah == ["ID", "Action", "Owner", "Due"],
     "Action Items header must be | ID | Action | Owner | Due |, got " + str(ah))
need(len(ab) == 5, "expected 5 action rows, got %d" % len(ab))
need([r[0] for r in ab] == ["A1", "A2", "A3", "A4", "A5"],
     "action ids must be A1..A5 in order, got " + str([r[0] for r in ab]))
expect_aowners = ["Dmitri Sokolov", "Hannah Steiner", "Lena Okoro",
                  "Takeshi Mori", "Ayo Adeyemi"]
got_aowners = [r[2] for r in ab]
need(got_aowners == expect_aowners,
     "action owners wrong:\n  expected %r\n  got      %r" % (expect_aowners, got_aowners))
expect_due = ["2026-03-09", "2026-03-11", "2026-03-13", "2026-03-05", "2026-03-17"]
got_due = [r[3] for r in ab]
need(got_due == expect_due,
     "due dates wrong:\n  expected %r\n  got      %r" % (expect_due, got_due))

print("ok")
