"""Edge checks: incomplete pages excluded, tag counts sourced correctly."""
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


def section(text, heading):
    ls = [l.rstrip() for l in text.split("\n")]
    idx = None
    for k, l in enumerate(ls):
        if l.strip() == heading:
            idx = k
            break
    need(idx is not None, "missing heading: " + heading)
    out = []
    for l in ls[idx + 1:]:
        if l.strip().startswith("## "):
            break
        out.append(l)
    return "\n".join(out)


doc = read("INDEX.md")
pages = section(doc, "## Pages")
tags = section(doc, "## Tags")
inc = section(doc, "## Incomplete Front Matter")

# pages with incomplete front matter never appear in the table
for path in ("billing-faq.md", "legacy-notes.md", "mobile-release.md", "search-arch.md"):
    need(path not in pages,
         "%s has incomplete front matter and must not be listed as a page" % path)
    need(path in inc, "%s must be listed under Incomplete Front Matter" % path)

# the non-markdown file is not a page
need("assets-note" not in doc, "assets-note.txt is not a markdown page")

# all eight complete pages are present exactly once
for path in ("deploys.md", "postgres-upgrade.md", "api-style.md", "oncall-rota.md",
             "onboarding.md", "incident-response.md", "data-retention.md", "glossary.md"):
    need(doc.count(path) == 1,
         "content/%s should appear exactly once, found %d" % (path, doc.count(path)))

# paths use forward slashes and stay relative to the project root
for m in re.findall(r"content[/\\][a-z0-9\-]+\.md", doc):
    need("\\" not in m, "paths must use forward slashes, got %r" % m)

# tag counts come only from the indexed pages
need("search:" not in tags and "architecture:" not in tags,
     "tags from a page with incomplete front matter must not be counted")
need("billing:" not in tags, "tags from billing-faq.md must not be counted")
need("mobile:" not in tags, "tags from mobile-release.md must not be counted")

pairs = []
for line in tags.split("\n"):
    s = line.strip()
    if s.startswith("- "):
        m = re.fullmatch(r"([a-z][a-z0-9\-]*): (\d+)", s[2:].strip())
        need(m, "each tag bullet must read '- <tag>: <count>', got %r" % s)
        pairs.append((m.group(1), int(m.group(2))))
need(len(pairs) == 8, "expected 8 distinct tags, got %d" % len(pairs))
need(sum(c for _, c in pairs) == 14,
     "the tag counts must total 14 across the indexed pages, got %d"
     % sum(c for _, c in pairs))
keys = [(-c, t) for t, c in pairs]
need(keys == sorted(keys),
     "tags must be sorted by count descending then name ascending, got %r" % (pairs,))

# missing-field lists keep the front-matter field order
for line in inc.split("\n"):
    s = line.strip()
    if s.startswith("- "):
        m = re.search(r"\(missing: ([^)]+)\)$", s)
        need(m, "each bullet must end with '(missing: <fields>)', got %r" % s)
        fields = [f.strip() for f in m.group(1).split(",")]
        order = ["title", "status", "owner", "updated"]
        need(all(f in order for f in fields), "unknown field name in %r" % s)
        need([order.index(f) for f in fields] == sorted(order.index(f) for f in fields),
             "missing fields must be listed in the order title, status, owner, "
             "updated; got %r" % s)

print("ok")
