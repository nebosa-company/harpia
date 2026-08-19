"""Core checks: every term covered once, with a correct occurrence list."""
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


terms = [l.strip() for l in read("terms.txt").split("\n")
         if l.strip() and not l.strip().startswith("#")]
need(terms, "terms.txt lists no terms")

files = sorted(f for f in os.listdir("corpus") if f.endswith(".md"))
need(files, "no documents in corpus/")
flat = {f: re.sub(r"\s+", " ", read(os.path.join("corpus", f)).lower())
        for f in files}

occurs = {}
for t in terms:
    key = re.sub(r"\s+", " ", t.lower())
    occurs[t] = [f for f in files if key in flat[f]]

found = sorted((t for t in terms if occurs[t]), key=str.lower)
missing = sorted((t for t in terms if not occurs[t]), key=str.lower)

doc = read("GLOSSARY.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Glossary", "the file must open with '# Glossary', got " + repr(first))
for h in ("## Terms", "## Not found"):
    need(any(l.strip() == h for l in lines), "missing heading: " + h)

entries, cur = [], None
in_terms = False
for l in lines:
    s = l.strip()
    if s == "## Terms":
        in_terms = True
        continue
    if s.startswith("## ") and s != "## Terms":
        in_terms = False
        cur = None
        continue
    if in_terms and s.startswith("### "):
        cur = {"term": s[4:].strip(), "body": [], "occurs": None}
        entries.append(cur)
    elif cur is not None and s.startswith("Occurs in:"):
        cur["occurs"] = [p.strip() for p in s[len("Occurs in:"):].split(",") if p.strip()]
    elif cur is not None and s:
        cur["body"].append(s)

got_terms = [e["term"] for e in entries]
need(got_terms == found,
     "one entry per term that occurs in the corpus, in alphabetical order:\n"
     "  expected %r\n  got      %r" % (found, got_terms))

for e in entries:
    need(e["occurs"] is not None,
         "entry %r has no 'Occurs in:' line" % e["term"])
    need(e["occurs"] == occurs[e["term"]],
         "%r occurs in %r, but the entry says %r"
         % (e["term"], occurs[e["term"]], e["occurs"]))
    need(" ".join(e["body"]).strip(), "entry %r has no definition" % e["term"])

nf, seen = [], False
for l in lines:
    s = l.strip()
    if s == "## Not found":
        seen = True
        continue
    if seen:
        if s.startswith("## "):
            break
        if s.startswith("- "):
            nf.append(s[2:].strip())
need(nf == missing,
     "'Not found' must list exactly the terms with no occurrence, "
     "alphabetically:\n  expected %r\n  got      %r" % (missing, nf))

print("ok")
