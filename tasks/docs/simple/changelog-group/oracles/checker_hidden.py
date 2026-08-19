"""Core checks for CHANGELOG.md: every release, section and bullet."""
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


def parse(text):
    releases = []
    cur_rel = None
    cur_sec = None
    for raw in text.split("\n"):
        line = raw.rstrip()
        s = line.strip()
        if s.startswith("## ") and not s.startswith("### "):
            cur_rel = (s[3:].strip(), [])
            releases.append(cur_rel)
            cur_sec = None
        elif s.startswith("### "):
            need(cur_rel is not None, "a ### section appears before any ## release heading")
            cur_sec = (s[4:].strip(), [])
            cur_rel[1].append(cur_sec)
        elif s.startswith("- ") or s.startswith("* "):
            need(cur_sec is not None, "a bullet appears outside any ### section: " + s)
            cur_sec[1].append(s[2:].strip())
    return releases


doc = read("CHANGELOG.md")
first = next((l.strip() for l in doc.split("\n") if l.strip()), "")
need(first == "# Changelog", "the file must open with '# Changelog', got " + repr(first))

expect = [
    ("Unreleased", [
        ("Features", ["**api**: add cursor pagination to /v1/orders (2ab9d10)"]),
        ("Fixes", ["**search**: stop dropping the last page of results (7c1e0a4)"]),
        ("Other", ["**api**: document the cursor parameter (5e40c73)",
                   "**deps**: bump the internal http client (b18f2e6)"]),
    ]),
    ("v1.4.0 - 2026-02-20", [
        ("Breaking Changes", ["**billing**: drop the legacy invoice endpoint (88a2d4e)"]),
        ("Features", ["**billing**: add proration to subscription upgrades (c07e5aa)"]),
        ("Fixes", ["**auth**: refresh tokens no longer expire early (41d8b39)",
                   "correct the currency rounding on receipts (0c4a6d2)"]),
        ("Other", ["**billing**: split the invoice builder (9be1f75)"]),
    ]),
    ("v1.3.0 - 2026-01-16", [
        ("Features", ["**search**: faceted filters on the catalogue (1f9d23a)"]),
        ("Fixes", ["**search**: escape user input in the query builder (7ab0e41)"]),
        ("Other", ["**catalogue**: cache the facet counts (33c9f60)",
                   "**search**: cover the escaping path (d92be07)"]),
    ]),
    ("v1.2.0 - 2025-12-05", [
        ("Breaking Changes", ["**orders**: order ids become opaque strings (6d02b9e)"]),
        ("Fixes", ["**orders**: stop double-charging on retried webhooks (b7c3a15)"]),
        ("Other", ["add the webhook retry guide (20e9df4)"]),
    ]),
]

got = parse(doc)
need([r[0] for r in got] == [r[0] for r in expect],
     "release headings wrong:\n  expected %r\n  got      %r"
     % ([r[0] for r in expect], [r[0] for r in got]))

for (rel, sections), (_, exp_sections) in zip(got, expect):
    need([s[0] for s in sections] == [s[0] for s in exp_sections],
         "sections under '## %s' wrong:\n  expected %r\n  got      %r"
         % (rel, [s[0] for s in exp_sections], [s[0] for s in sections]))
    for (sec, bullets), (_, exp_bullets) in zip(sections, exp_sections):
        need(bullets == exp_bullets,
             "bullets under '%s / %s' wrong:\n  expected %r\n  got      %r"
             % (rel, sec, exp_bullets, bullets))

print("ok")
