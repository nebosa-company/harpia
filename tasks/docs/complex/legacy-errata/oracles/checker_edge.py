"""Edge checks: the errata table finds every contradiction and invents none."""
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


def norm(s):
    return re.sub(r"\s+", " ", s).strip().lower()


doc = read("ERRATA.md")
first = next((l.strip() for l in doc.split("\n") if l.strip()), "")
need(first == "# Errata", "the file must open with '# Errata', got " + repr(first))

rows = []
for l in doc.split("\n"):
    s = l.strip()
    if s.startswith("|"):
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not all(c and set(c) <= set("-: ") for c in cells):
            rows.append(cells)
need(rows, "ERRATA.md has no markdown table")
need(rows[0] == ["Topic", "Kept", "Kept source", "Superseded", "Superseded source"],
     "the header must be | Topic | Kept | Kept source | Superseded | "
     "Superseded source |, got %r" % (rows[0],))
body = [r for r in rows[1:] if len(r) == 5]
need(len(body) == len(rows) - 1, "every errata row must have 5 cells")

expected = {
    ("30 minutes", "1 hour"): ("service-policy.md", "wiki-support.md",
                               ["sev 1", "sev1", "response"]),
    ("90 days", "180 days"): ("service-policy.md", "onboarding-deck.md",
                              ["operational log", "log retention", "retention"]),
    ("once a quarter", "once a year"): ("backup-standard.md", "faq.md",
                                        ["restore", "backup"]),
    ("2 gb", "5 gb"): ("runbook-export.md", "onboarding-deck.md",
                       ["export", "split"]),
    ("wednesday", "monday"): ("wiki-support.md", "onboarding-deck.md",
                              ["handover", "rota", "on-call"]),
    ("two approvals", "one approval"): ("service-policy.md", "faq.md",
                                        ["review", "approval", "schema"]),
}

need(len(body) == 6,
     "there are six disagreements across the document set; the errata has %d rows"
     % len(body))

seen = set()
for row in body:
    topic, kept, kept_src, sup, sup_src = row
    key = (norm(kept), norm(sup))
    need(key in expected,
         "this row is not one of the disagreements in the set: kept %r, "
         "superseded %r" % (kept, sup))
    need(key not in seen, "the same disagreement is listed twice: %r" % (key,))
    seen.add(key)
    want_kept_src, want_sup_src, topic_alts = expected[key]
    need(norm(kept_src) == want_kept_src,
         "%r is stated by %s, not by %r" % (kept, want_kept_src, kept_src))
    need(norm(sup_src) == want_sup_src,
         "%r is stated by %s, not by %r" % (sup, want_sup_src, sup_src))
    need(any(a in norm(topic) for a in topic_alts),
         "the topic cell must say what the disagreement is about (one of %r), "
         "got %r" % (topic_alts, topic))
need(len(seen) == 6, "every disagreement must appear exactly once")

# sources are bare file names that exist
for row in body:
    for cell in (row[2], row[4]):
        need("/" not in cell and "\\" not in cell,
             "name the source by bare file name, got %r" % cell)
        need(os.path.isfile(os.path.join("legacy", cell)),
             "no such document in legacy/: %r" % cell)

# facts only one document states are not disagreements
low = doc.lower()
for clean in ["72 hour", "35 day", "400 day", "48 hour", "20 minute",
              "escalat", "500 mb"]:
    need(clean not in low,
         "%r is stated by only one document and is not in dispute" % clean)

print("ok")
