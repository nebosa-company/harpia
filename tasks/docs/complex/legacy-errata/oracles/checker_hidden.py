"""Core checks: the corrected master document carries the winning facts."""
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


doc = read("MASTER.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Kestrel Operations Reference",
     "the file must open with '# Kestrel Operations Reference', got " + repr(first))

want_sections = ["## Support commitments", "## Data retention",
                 "## Backup and restore", "## Data export", "## On-call",
                 "## Change management"]
got_sections = [l.strip() for l in lines if l.strip().startswith("## ")]
need(got_sections == want_sections,
     "the master must carry exactly these sections in this order:\n"
     "  expected %r\n  got      %r" % (want_sections, got_sections))


def section(heading):
    idx = next(i for i, l in enumerate(lines) if l.strip() == heading)
    out = []
    for l in lines[idx + 1:]:
        if l.strip().startswith("## "):
            break
        out.append(l.strip())
    return " ".join(out).strip()


# heading -> (facts that must survive, facts that must not)
checks = {
    "## Support commitments": (["30 minutes", "4 hours"], ["1 hour"]),
    "## Data retention": (["90 days", "400 days"], ["180 days"]),
    "## Backup and restore": (["once a quarter", "35 days"], ["once a year"]),
    "## Data export": (["2 GB", "500 MB", "72 hours"], ["5 GB"]),
    "## On-call": (["Wednesday", "primary", "secondary"], ["Monday"]),
    "## Change management": (["two approvals", "did not write it"], ["one approval"]),
}
for heading, (keep, drop) in checks.items():
    body = section(heading)
    low = body.lower()
    need(len(body.split()) >= 25,
         "%s is too thin to replace the documents it merges (%d words)"
         % (heading, len(body.split())))
    for fact in keep:
        need(fact.lower() in low,
             "%s must carry the settled figure %r" % (heading, fact))
    for bad in drop:
        need(bad.lower() not in low,
             "%s still states %r, which the precedence rules rule out"
             % (heading, bad))

# the superseded values must not survive anywhere in the master
low_all = doc.lower()
for bad in ("180 days", "5 gb", "once a year", "one approval"):
    need(bad not in low_all,
         "the master still states %r somewhere, which is the superseded value" % bad)
need(not re.search(r"\bmonday\b", low_all),
     "the master still gives Monday as the handover day")
need(not re.search(r"\b1 hour\b", low_all),
     "the master still gives 1 hour as the Sev 1 response target")

print("ok")
