"""Core checks for INDEX.md."""
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


doc = read("INDEX.md")
ls = lines_of(doc)
first = next((l.strip() for l in ls if l.strip()), "")
need(first == "# Documentation Index",
     "the file must open with '# Documentation Index', got " + repr(first))

pos = [find_heading(ls, h) for h in
       ("## Pages", "## Tags", "## Incomplete Front Matter")]
need(pos == sorted(pos),
     "sections must run Pages, Tags, Incomplete Front Matter")

header, body = table_after(doc, "## Pages")
expect_header = ["Title", "Path", "Status", "Owner", "Updated"]
need(header == expect_header,
     "Pages header must be %r, got %r" % (expect_header, header))
expect = [
    ["Deploy Runbook", "content/deploys.md", "published", "Hannah Steiner", "2026-03-02"],
    ["Postgres 16 Upgrade", "content/postgres-upgrade.md", "draft", "Dmitri Sokolov", "2026-03-02"],
    ["API Style Guide", "content/api-style.md", "published", "Lena Okoro", "2026-02-19"],
    ["On-call Rota", "content/oncall-rota.md", "published", "Takeshi Mori", "2026-02-19"],
    ["Onboarding", "content/onboarding.md", "published", "Priya Raman", "2026-02-11"],
    ["Incident Response", "content/incident-response.md", "published", "Takeshi Mori", "2026-01-28"],
    ["Data Retention", "content/data-retention.md", "review", "Ayo Adeyemi", "2026-01-09"],
    ["Glossary", "content/glossary.md", "review", "Priya Raman", "2025-12-14"],
]
need(len(body) == len(expect),
     "expected %d complete pages, got %d rows" % (len(expect), len(body)))
for got, want in zip(body, expect):
    need(len(got) == 5, "page row must have 5 cells: %r" % (got,))
    need(got[0] == want[0],
         "pages must be sorted by Updated descending then Title ascending; "
         "expected %r here, got %r" % (want[0], got[0]))
    for col, g, w in zip(expect_header, got, want):
        need(g == w, "%s: %s expected %r, got %r" % (want[0], col, w, g))

tags = bullets_after(doc, "## Tags")
expect_tags = ["ops: 3", "oncall: 2", "people: 2", "process: 2", "reference: 2",
               "api: 1", "database: 1", "policy: 1"]
need(tags == expect_tags,
     "Tags section wrong:\n  expected %r\n  got      %r" % (expect_tags, tags))

inc = bullets_after(doc, "## Incomplete Front Matter")
expect_inc = [
    "content/billing-faq.md (missing: status, updated)",
    "content/legacy-notes.md (missing: title, status, owner, updated)",
    "content/mobile-release.md (missing: title)",
    "content/search-arch.md (missing: owner)",
]
need(inc == expect_inc,
     "Incomplete Front Matter wrong:\n  expected %r\n  got      %r" % (expect_inc, inc))

print("ok")
