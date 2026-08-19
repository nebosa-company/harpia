"""Core checks: coverage, sourcing and placement of every FAQ entry."""
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


def front_matter(text):
    lines = text.split("\n")
    need(lines and lines[0].strip() == "---", "ticket has no front matter")
    meta = {}
    for l in lines[1:]:
        if l.strip() == "---":
            break
        if ":" in l:
            k, v = l.split(":", 1)
            meta[k.strip()] = v.strip()
    return meta


tickets = {}
for name in sorted(os.listdir("tickets")):
    if name.endswith(".md"):
        meta = front_matter(read(os.path.join("tickets", name)))
        tickets[meta["id"]] = meta

resolved = sorted(t for t, m in tickets.items() if m["status"] == "resolved")
excluded = sorted(t for t, m in tickets.items() if m["status"] != "resolved")
need(len(resolved) == 12,
     "the corpus should hold 12 resolved tickets, checker found %d" % len(resolved))

doc = read("FAQ.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Support FAQ",
     "the file must open with '# Support FAQ', got " + repr(first))

cats = [l.strip()[3:].strip() for l in lines
        if l.strip().startswith("## ") and not l.strip().startswith("### ")]
need(cats == ["Accounts", "Billing", "Data Export", "Integrations"],
     "the four category headings must appear once each in that order, got %r" % (cats,))

# walk the document, collecting entries with their category
entries = []
cur_cat = None
cur = None
for l in lines:
    s = l.strip()
    if s.startswith("## ") and not s.startswith("### "):
        cur_cat, cur = s[3:].strip(), None
    elif s.startswith("### "):
        cur = {"cat": cur_cat, "q": s[4:].strip(), "body": [], "sources": None}
        entries.append(cur)
    elif cur is not None:
        if s.startswith("Source:"):
            need(cur["sources"] is None,
                 "entry %r has more than one Source line" % cur["q"])
            cur["sources"] = [p.strip() for p in s[len("Source:"):].split(",") if p.strip()]
        else:
            cur["body"].append(s)

need(entries, "FAQ.md has no ### entries")

cited = []
for e in entries:
    need(e["cat"] is not None, "entry %r sits outside any category" % e["q"])
    need(e["q"].endswith("?"), "every entry heading must be a question: %r" % e["q"])
    need(e["sources"], "entry %r has no 'Source:' line" % e["q"])
    need("".join(e["body"]).strip(), "entry %r has no answer text" % e["q"])
    for tid in e["sources"]:
        need(re.fullmatch(r"SUP-\d{4}", tid),
             "Source ids look like SUP-4101, got %r" % tid)
        need(tid in tickets, "entry %r cites a ticket that does not exist: %s"
             % (e["q"], tid))
        need(tickets[tid]["status"] == "resolved",
             "entry %r cites %s, which is not resolved" % (e["q"], tid))
        need(tickets[tid]["area"] == e["cat"],
             "%s belongs to the %s area but is cited under %s"
             % (tid, tickets[tid]["area"], e["cat"]))
    need(e["sources"] == sorted(e["sources"]),
         "Source ids must be listed in ascending order: %r" % e["sources"])
    cited.extend(e["sources"])

dupes = sorted({t for t in cited if cited.count(t) > 1})
need(not dupes, "these tickets are cited by more than one entry: %r" % dupes)
missing = [t for t in resolved if t not in cited]
need(not missing, "these resolved tickets are not covered anywhere: %r" % missing)
for t in excluded:
    need(t not in doc, "%s is not resolved and must not appear in the FAQ" % t)

print("ok")
