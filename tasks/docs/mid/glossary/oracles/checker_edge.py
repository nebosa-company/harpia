"""Edge checks: definitions grounded in the corpus, nothing invented."""
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


doc = read("GLOSSARY.md")
lines = [l.rstrip() for l in doc.split("\n")]

entries, cur = {}, None
order = []
for l in lines:
    s = l.strip()
    if s.startswith("### "):
        cur = s[4:].strip()
        entries[cur] = []
        order.append(cur)
    elif s.startswith("## "):
        cur = None
    elif cur is not None and s and not s.startswith("Occurs in:"):
        entries[cur].append(s)
need(entries, "GLOSSARY.md has no term entries")

facts = {
    "error budget": ["0.1", "30 day", "43 minutes"],
    "maxmemory": ["12 gb", "8 gb"],
    "on-call rota": ["pager", "reachable", "release manager"],
    "replication slot": ["200"],
    "golden signal": ["saturation"],
    "incident commander": ["timeline", "communicat", "comms", "debug"],
    "subject access request": ["30"],
    "canary deploy": ["five percent", "5 percent", "5%", "ten minutes"],
}
for term, alts in facts.items():
    need(term in entries, "missing entry for %r" % term)
    text = " ".join(entries[term]).lower()
    need(any(a in text for a in alts),
         "the definition of %r must come from the corpus (expected one of %r)"
         % (term, alts))

for term, body in entries.items():
    words = " ".join(body).split()
    need(len(words) >= 12,
         "the definition of %r is too short to be a definition (%d words)"
         % (term, len(words)))
    low = " ".join(body).lower()
    for bad in ("tbd", "fixme", "todo:", "not defined here", "see above"):
        need(bad not in low, "the definition of %r is a placeholder: %s" % (term, bad))

# terms with no occurrence get no definition
for absent in ("dark launch", "shadow traffic"):
    need(absent not in entries,
         "%r does not occur in the corpus and must not be defined" % absent)

# occurrence lists name real corpus files, bare, alphabetical
corpus = set(f for f in os.listdir("corpus") if f.endswith(".md"))
count = 0
for l in lines:
    s = l.strip()
    if s.startswith("Occurs in:"):
        count += 1
        names = [p.strip() for p in s[len("Occurs in:"):].split(",") if p.strip()]
        need(names, "an 'Occurs in:' line lists no documents")
        for n in names:
            need(n in corpus, "no such document in corpus/: %r" % n)
            need("/" not in n and "\\" not in n,
                 "list documents by bare file name, got %r" % n)
        need(names == sorted(names), "documents must be listed alphabetically: %r" % s)
        need(len(set(names)) == len(names), "a document is listed twice: %r" % s)
need(count == len(entries),
     "every entry needs exactly one 'Occurs in:' line (%d entries, %d lines)"
     % (len(entries), count))

need(order == sorted(order, key=str.lower),
     "entries must be in alphabetical order, got %r" % order)

print("ok")
