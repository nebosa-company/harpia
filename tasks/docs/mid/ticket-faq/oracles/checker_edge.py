"""Edge checks: duplicates merged, answers carry the resolution's facts."""
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


doc = read("FAQ.md")
lines = [l.rstrip() for l in doc.split("\n")]

entries = []
cur = None
for l in lines:
    s = l.strip()
    if s.startswith("### "):
        cur = {"q": s[4:].strip(), "text": [], "sources": []}
        entries.append(cur)
    elif cur is not None:
        if s.startswith("Source:"):
            cur["sources"] = [p.strip() for p in s[len("Source:"):].split(",") if p.strip()]
        else:
            cur["text"].append(s)
need(entries, "FAQ.md has no ### entries")

for e in entries:
    e["all"] = (e["q"] + " " + " ".join(e["text"])).lower()

# a ticket marked duplicate_of another must be answered in the same entry
pairs = [("SUP-4102", "SUP-4101"), ("SUP-4121", "SUP-4120"), ("SUP-4131", "SUP-4130")]
for dup, primary in pairs:
    home = [e for e in entries if dup in e["sources"]]
    need(len(home) == 1, "%s must be cited by exactly one entry" % dup)
    need(primary in home[0]["sources"],
         "%s is a duplicate of %s, so both must be answered by the same entry "
         "(entry %r cites %r)" % (dup, primary, home[0]["q"], home[0]["sources"]))

need(len(entries) == 9,
     "with the three duplicate pairs merged there are 9 distinct questions, "
     "got %d entries" % len(entries))

# each answer has to carry the fact the ticket actually turned on
facts = {
    "SUP-4101": ["prorat", "pro rata", "pro-rata"],
    "SUP-4103": ["credit note"],
    "SUP-4110": ["admin"],
    "SUP-4111": ["at least one", "last admin", "only admin", "final admin"],
    "SUP-4120": ["2 gb", "500 mb"],
    "SUP-4122": ["72 hour", "72-hour", "72 h"],
    "SUP-4130": ["delivery_id", "delivery id"],
    "SUP-4132": ["30 minute", "30 min", "five times", "5 times"],
    "SUP-4133": ["203.0.113.0/24"],
}
for tid, alts in facts.items():
    home = [e for e in entries if tid in e["sources"]]
    need(len(home) == 1, "%s must be cited by exactly one entry" % tid)
    text = home[0]["all"]
    need(any(a in text for a in alts),
         "the answer sourced from %s must state its resolution (expected one of "
         "%r in entry %r)" % (tid, alts, home[0]["q"]))

# nothing from the open or wontfix tickets leaks in
low = doc.lower()
for phrase in ["purchase order", "po number", "custom role", "wontfix"]:
    need(phrase not in low,
         "%r comes from a ticket that is not resolved and must not appear" % phrase)

for e in entries:
    need(len(" ".join(e["text"]).split()) >= 20,
         "entry %r needs a real answer, not a stub" % e["q"])

print("ok")
