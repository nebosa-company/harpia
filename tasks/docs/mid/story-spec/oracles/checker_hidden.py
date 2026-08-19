"""Core checks: one requirement per accepted criterion, both ways traceable."""
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


def load_backlog():
    text = read(os.path.join("stories", "backlog.md"))
    stories, cur = [], None
    in_ac = False
    for raw in text.split("\n"):
        s = raw.strip()
        m = re.match(r"^## (US-\d\d):", s)
        if m:
            cur = {"id": m.group(1), "status": None, "criteria": []}
            stories.append(cur)
            in_ac = False
            continue
        if cur is None:
            continue
        if s.lower().startswith("status:"):
            cur["status"] = s.split(":", 1)[1].strip().lower()
        elif s.lower().startswith("acceptance criteria"):
            in_ac = True
        elif in_ac and s.startswith("- "):
            cur["criteria"].append(s[2:].strip())
        elif in_ac and s and not s.startswith("- "):
            in_ac = False
    return stories


stories = load_backlog()
accepted = [s for s in stories if s["status"] == "accepted"]
rejected = [s for s in stories if s["status"] != "accepted"]
need(len(stories) == 12, "the backlog should hold 12 stories, found %d" % len(stories))
need(len(accepted) == 10, "10 of them are accepted, found %d" % len(accepted))

expected = []
for s in accepted:
    for c in s["criteria"]:
        expected.append((s["id"], c))
need(len(expected) == 28,
     "the accepted stories carry 28 acceptance criteria, found %d" % len(expected))

doc = read("SPEC.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Billing Console Specification",
     "the file must open with '# Billing Console Specification', got " + repr(first))
for h in ("## Requirements", "## Traceability"):
    need(any(l.strip() == h for l in lines), "missing heading: " + h)

reqs, cur = [], None
for l in lines:
    s = l.strip()
    if s.startswith("### "):
        cur = {"id": s[4:].strip(), "text": [], "source": None}
        reqs.append(cur)
    elif cur is not None and s.startswith("Source:"):
        cur["source"] = s.split(":", 1)[1].strip()
    elif cur is not None and s and not s.startswith("|") and not s.startswith("#"):
        cur["text"].append(s)

need(len(reqs) == len(expected),
     "expected %d requirements, one per acceptance criterion of an accepted "
     "story; got %d" % (len(expected), len(reqs)))

for i, (r, (story, _crit)) in enumerate(zip(reqs, expected)):
    want_id = "R-%03d" % (i + 1)
    need(r["id"] == want_id,
         "requirement %d must be headed %r, got %r" % (i + 1, want_id, r["id"]))
    need(" ".join(r["text"]).strip(),
         "%s has no requirement text" % want_id)
    need(r["source"] == story,
         "%s comes from %s, but its Source line says %r" % (want_id, story, r["source"]))

# traceability table
rows = []
for l in lines:
    s = l.strip()
    if s.startswith("|"):
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not all(c and set(c) <= set("-: ") for c in cells):
            rows.append(cells)
need(rows, "SPEC.md has no traceability table")
need(rows[0] == ["Story", "Requirements"],
     "the traceability header must be | Story | Requirements |, got %r" % (rows[0],))
body = rows[1:]

want_map = []
n = 0
for s in accepted:
    ids = ["R-%03d" % (n + k + 1) for k in range(len(s["criteria"]))]
    n += len(s["criteria"])
    want_map.append([s["id"], ", ".join(ids)])
need(len(body) == len(want_map),
     "the table must hold one row per accepted story (%d), got %d"
     % (len(want_map), len(body)))
for got, want in zip(body, want_map):
    need(got[0] == want[0],
         "traceability rows must follow story order; expected %s, got %s"
         % (want[0], got[0]))
    need(got[1] == want[1],
         "%s: requirements must be %r, got %r" % (want[0], want[1], got[1]))

for s in rejected:
    need(s["id"] not in doc,
         "%s was rejected and must not appear in the specification" % s["id"])

print("ok")
