"""Edge checks: anchors resolve, collisions numbered, body untouched."""
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


def slug(text):
    s = text.lower()
    s = "".join(c for c in s if c.isalnum() or c in " -")
    return s.replace(" ", "-")


doc = read("handbook.md")
original = read(os.path.join("_ref", "handbook-original.md"))
lines = [l.rstrip() for l in doc.split("\n")]

# rebuild the anchor table the renderer would produce, skipping Contents
anchors = {}
seen = {}
for l in lines:
    s = l.strip()
    if s.startswith("## ") or s.startswith("### "):
        text = s.lstrip("#").strip()
        if text == "Contents":
            continue
        base = slug(text)
        n = seen.get(base, 0)
        seen[base] = n + 1
        anchors.setdefault(text, []).append(base if n == 0 else "%s-%d" % (base, n))

# every link in the Contents section must resolve to one of them
h2s = [i for i, l in enumerate(lines)
       if l.startswith("## ") and not l.startswith("### ")]
need(h2s and lines[h2s[0]].strip() == "## Contents",
     "the Contents section is missing")
toc = [l for l in lines[h2s[0] + 1:h2s[1]] if l.strip()]

used = []
for entry in toc:
    m = re.fullmatch(r"( *)- \[(.+)\]\(#([a-z0-9\-]+)\)", entry)
    need(m, "each entry must read '- [Heading](#anchor)', got %r" % entry)
    indent, text, anchor = m.group(1), m.group(2), m.group(3)
    need(len(indent) in (0, 2),
         "level-2 entries are flush left and level-3 entries indented by two "
         "spaces, got %d in %r" % (len(indent), entry))
    need(text in anchors, "no heading in the document reads %r" % text)
    need(anchor in anchors[text],
         "anchor %r does not match heading %r (expected one of %r)"
         % (anchor, text, anchors[text]))
    used.append(anchor)

need(len(set(used)) == len(used),
     "two contents entries point at the same anchor: %r"
     % [a for a in used if used.count(a) > 1])
need(sorted(a for a in used if a.startswith("code-review")) ==
     ["code-review", "code-review-1", "code-review-2"],
     "the three 'Code Review' headings must get distinct numbered anchors, got %r"
     % sorted(a for a in used if a.startswith("code-review")))

# every heading outside the Contents section is listed exactly once
listed = [re.fullmatch(r" *- \[(.+)\]\(#[a-z0-9\-]+\)", e).group(1) for e in toc]
headings = [l.strip().lstrip("#").strip() for l in lines
            if l.strip().startswith("## ") or l.strip().startswith("### ")]
headings = [h for h in headings if h != "Contents"]
need(len(listed) == len(headings),
     "the contents must list every level-2 and level-3 heading exactly once "
     "(%d headings, %d entries)" % (len(headings), len(listed)))
need(listed == headings,
     "contents entries must follow document order:\n  headings %r\n  entries  %r"
     % (headings, listed))

# nothing else in the handbook changed
def strip_toc(text):
    out, skipping = [], False
    for l in text.split("\n"):
        s = l.strip()
        if s == "## Contents":
            skipping = True
            continue
        if skipping:
            if s.startswith("## ") and not s.startswith("### "):
                skipping = False
            else:
                continue
        if s:
            out.append(l.rstrip())
    return out


need(strip_toc(doc) == strip_toc(original),
     "the rest of handbook.md must be left exactly as it was")

print("ok")
