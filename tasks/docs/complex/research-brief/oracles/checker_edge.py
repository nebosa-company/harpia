"""Edge checks: every quotation matches the lines it cites, index agrees."""
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


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


def span(path, a, b):
    local = path.replace("/", os.sep)
    need(os.path.isfile(local), "citation points at a file that does not exist: %r" % path)
    src = read(local).split("\n")
    need(1 <= a <= b <= len(src),
         "%s has %d lines; the citation asks for %d-%d" % (path, len(src), a, b))
    return flat(" ".join(src[a - 1:b]))


doc = read("BRIEF.md")
lines = [l.rstrip() for l in doc.split("\n")]

findings = [l.strip()[4:].strip() for l in lines if l.strip().startswith("### ")]
need(len(findings) == 5,
     "the brief carries five findings, got %d" % len(findings))
for i, f in enumerate(findings, 1):
    need(re.match(r"^F%d\. \S" % i, f),
         "finding %d must be headed 'F%d. <statement>', got %r" % (i, i, f))

CITE = re.compile(r"^\[([^\]:]+):(\d+)-(\d+)\]$")

# collect quotation blocks and the citation that follows each
citations = []
i = 0
current_finding = None
while i < len(lines):
    s = lines[i].strip()
    if s.startswith("### "):
        current_finding = s[4:].strip()
    if s.startswith(">"):
        quote, start = [], i
        while i < len(lines) and lines[i].strip().startswith(">"):
            quote.append(lines[i].strip().lstrip(">").strip())
            i += 1
        j = i
        while j < len(lines) and not lines[j].strip():
            j += 1
        need(j < len(lines), "a quotation at line %d has no citation after it" % (start + 1))
        m = CITE.match(lines[j].strip())
        need(m, "a quotation must be followed by a citation like "
                "[sources/interviews.md:14-16], got %r" % lines[j].strip())
        path, a, b = m.group(1), int(m.group(2)), int(m.group(3))
        text = flat(" ".join(quote)).strip('"')
        actual = span(path, a, b)
        need(text == actual,
             "the quotation does not match %s lines %d-%d:\n  cited  %r\n  quoted %r"
             % (path, a, b, actual, text))
        citations.append((current_finding, path, "%d-%d" % (a, b)))
        i = j + 1
        continue
    i += 1

need(len(citations) >= 6,
     "the findings must be evidenced by at least six quotations, got %d"
     % len(citations))
need(len({c[1] for c in citations}) >= 3,
     "the evidence must come from at least three different sources, got %d"
     % len({c[1] for c in citations}))
need(len({c[0] for c in citations}) == 5,
     "every finding needs at least one quotation of its own; %d of 5 have one"
     % len({c[0] for c in citations}))

# every citation appears once in the evidence index, in order
idx = next((k for k, l in enumerate(lines) if l.strip() == "## Evidence index"), None)
need(idx is not None, "missing heading: ## Evidence index")
rows = []
for l in lines[idx + 1:]:
    s = l.strip()
    if s.startswith("|"):
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not all(c and set(c) <= set("-: ") for c in cells):
            rows.append(cells)
need(rows, "no table under ## Evidence index")
need(rows[0] == ["Ref", "Source", "Lines"],
     "the evidence index header must be | Ref | Source | Lines |, got %r" % (rows[0],))
body = rows[1:]
need(len(body) == len(citations),
     "the evidence index must hold one row per quotation (%d), got %d"
     % (len(citations), len(body)))
for n, (row, cit) in enumerate(zip(body, citations), 1):
    need(len(row) == 3, "index row must have 3 cells: %r" % (row,))
    need(row[0] == "E%d" % n,
         "index refs run E1, E2, ... in the order the quotations appear; "
         "expected E%d, got %r" % (n, row[0]))
    need(row[1] == cit[1],
         "index row E%d source must be %r, got %r" % (n, cit[1], row[1]))
    need(row[2] == cit[2],
         "index row E%d lines must be %r, got %r" % (n, cit[2], row[2]))

# recommendations are tied back to findings
rec_idx = next((k for k, l in enumerate(lines) if l.strip() == "## Recommendations"), None)
need(rec_idx is not None, "missing heading: ## Recommendations")
recs, buf = [], None
for l in lines[rec_idx + 1:]:
    s = l.strip()
    if s.startswith("## "):
        break
    if s.startswith("- "):
        if buf is not None:
            recs.append(buf)
        buf = s[2:].strip()
    elif buf is not None and s:
        buf += " " + s
if buf is not None:
    recs.append(buf)
need(len(recs) >= 3, "the brief needs at least three recommendations, got %d" % len(recs))
for r in recs:
    need(len(r.split()) >= 8, "recommendation is too thin to act on: %r" % r)
    need(re.search(r"\bF[1-5]\b", r),
         "each recommendation must name the finding it rests on: %r" % r)

print("ok")
