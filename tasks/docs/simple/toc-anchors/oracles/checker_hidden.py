"""Core checks: the Contents block and its anchors."""
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


doc = read("handbook.md")
lines = [l.rstrip() for l in doc.split("\n")]

# the Contents section sits between the intro and the first real section
h2s = [i for i, l in enumerate(lines)
       if l.startswith("## ") and not l.startswith("### ")]
need(h2s, "handbook.md has no level-2 headings any more")
need(lines[h2s[0]].strip() == "## Contents",
     "the first level-2 heading must be '## Contents', got %r" % lines[h2s[0]])
need(len(h2s) >= 2, "the Contents section must come before the first real section")
need(lines[h2s[1]].strip() == "## Working Agreements",
     "'## Working Agreements' must follow the Contents section, got %r"
     % lines[h2s[1]])

toc = [l for l in lines[h2s[0] + 1:h2s[1]] if l.strip()]
expect = [
    "- [Working Agreements](#working-agreements)",
    "  - [Code Review](#code-review)",
    "  - [Pairing](#pairing)",
    "- [Delivery](#delivery)",
    "  - [Code Review](#code-review-1)",
    "  - [Release Trains](#release-trains)",
    "- [Operations](#operations)",
    "  - [On-call](#on-call)",
    "  - [Incident Response (Sev 1 & Sev 2)](#incident-response-sev-1--sev-2)",
    "- [Data & Privacy](#data--privacy)",
    "  - [Retention](#retention)",
    "  - [Access Requests](#access-requests)",
    "- [FAQ](#faq)",
    "  - [Code Review](#code-review-2)",
]
need(len(toc) == len(expect),
     "expected %d contents entries, got %d:\n%s"
     % (len(expect), len(toc), "\n".join(toc)))
for i, (got, want) in enumerate(zip(toc, expect)):
    need(got == want,
         "contents entry %d wrong:\n  expected %r\n  got      %r" % (i + 1, want, got))

print("ok")
