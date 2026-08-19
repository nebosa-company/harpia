"""Edge checks: release commits dropped, section order, bullet shape."""
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


doc = read("CHANGELOG.md")
low = doc.lower()

# the three chore(release) commits never appear in a changelog
for h in ("f30c9b1", "e5b70c8", "a4f81cc"):
    need(h not in doc, "release-bookkeeping commit %s must not appear" % h)
need("chore(release)" not in low, "a chore(release) subject leaked into the changelog")

# every other commit appears exactly once
for h in ("7c1e0a4", "2ab9d10", "5e40c73", "b18f2e6", "88a2d4e", "c07e5aa",
          "41d8b39", "9be1f75", "0c4a6d2", "1f9d23a", "7ab0e41", "33c9f60",
          "d92be07", "6d02b9e", "b7c3a15", "20e9df4"):
    need(doc.count(h) == 1,
         "commit %s should appear exactly once, found %d" % (h, doc.count(h)))

lines = [l.strip() for l in doc.split("\n")]

# releases run newest first, Unreleased at the top
rels = [l[3:].strip() for l in lines if l.startswith("## ") and not l.startswith("### ")]
need(rels[0] == "Unreleased", "the Unreleased section must come first")
need(rels[1:] == ["v1.4.0 - 2026-02-20", "v1.3.0 - 2026-01-16", "v1.2.0 - 2025-12-05"],
     "releases must run newest first with a '## <version> - <date>' heading, got %r" % rels[1:])

# section order within each release, and no empty sections
order = ["Breaking Changes", "Features", "Fixes", "Other"]
cur = []
groups = []
for l in lines:
    if l.startswith("## ") and not l.startswith("### "):
        if cur:
            groups.append(cur)
        cur = []
    elif l.startswith("### "):
        cur.append(l[4:].strip())
if cur:
    groups.append(cur)
for g in groups:
    need(all(s in order for s in g), "unknown section heading in %r" % g)
    need([order.index(s) for s in g] == sorted(order.index(s) for s in g),
         "sections must appear in the order %r, got %r" % (order, g))
    need(len(set(g)) == len(g), "a section heading is repeated inside one release: %r" % g)

need(groups[0] == ["Features", "Fixes", "Other"],
     "Unreleased has no breaking changes, so that section must be omitted: %r" % groups[0])
need(groups[2] == ["Features", "Fixes", "Other"],
     "v1.3.0 has no breaking changes, so that section must be omitted: %r" % groups[2])

# bullet shape
bullet = re.compile(r"^(?:\*\*[a-z]+\*\*: )?\S.*\([0-9a-f]{7}\)$")
count = 0
for l in lines:
    if l.startswith("- "):
        body = l[2:].strip()
        count += 1
        need(bullet.match(body),
             "bullet must read '- **scope**: subject (hash)' or '- subject (hash)': %r" % body)
        need(not re.match(r"^(feat|fix|docs|chore|perf|refactor|test)[(:!]", body),
             "the conventional-commit type must not survive into the bullet: %r" % body)
        need("!" not in body.split("(")[0],
             "the breaking '!' marker belongs in the section, not the bullet: %r" % body)
need(count == 16, "expected 16 bullets in total, got %d" % count)

print("ok")
