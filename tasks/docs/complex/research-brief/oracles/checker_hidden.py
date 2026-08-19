"""Core checks: structure, key numbers, and citations that resolve."""
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


def source_span(path, a, b):
    need(not os.path.isabs(path) and ".." not in path.split("/"),
         "citation paths are relative to the project root: %r" % path)
    local = path.replace("/", os.sep)
    need(os.path.isfile(local), "citation points at a file that does not exist: %r" % path)
    lines = read(local).split("\n")
    need(1 <= a <= b <= len(lines),
         "%s has %d lines; the citation asks for %d-%d" % (path, len(lines), a, b))
    return flat(" ".join(lines[a - 1:b]))


doc = read("BRIEF.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Research brief: export workflow friction",
     "the file must open with '# Research brief: export workflow friction', "
     "got " + repr(first))

want_sections = ["## Question", "## Method", "## Key numbers", "## Findings",
                 "## Recommendations", "## Evidence index"]
got_sections = [l.strip() for l in lines
                if l.strip().startswith("## ") and not l.strip().startswith("### ")]
need(got_sections == want_sections,
     "the brief must carry exactly these sections in this order:\n"
     "  expected %r\n  got      %r" % (want_sections, got_sections))


def table_under(heading):
    idx = next((i for i, l in enumerate(lines) if l.strip() == heading), None)
    need(idx is not None, "missing heading: " + heading)
    rows = []
    for l in lines[idx + 1:]:
        s = l.strip()
        if s.startswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if not all(c and set(c) <= set("-: ") for c in cells):
                rows.append(cells)
        elif s.startswith("## ") and rows:
            break
    need(rows, "no table under " + heading)
    return rows


rows = table_under("## Key numbers")
need(rows[0] == ["Question", "Answer", "Source", "Lines"],
     "the key numbers header must be | Question | Answer | Source | Lines |, got %r"
     % (rows[0],))
expected = [
    ("What share of survey respondents named the data export as the slowest part of their week?",
     "62%", "sources/survey-2026.md"),
    ("What is the median export duration, in minutes?", "18",
     "sources/product-telemetry.md"),
    ("What is the 95th percentile export duration, in minutes?", "71",
     "sources/product-telemetry.md"),
    ("How many tickets in the quarter mentioned an export timing out?", "137",
     "sources/support-analysis.md"),
    ("How many of those timeout tickets describe a run that had not failed at all?",
     "84", "sources/support-analysis.md"),
    ("How many usable responses did the survey receive?", "611",
     "sources/survey-2026.md"),
]
body = rows[1:]
need(len(body) == len(expected),
     "the key numbers table must answer the six questions asked, got %d rows"
     % len(body))
for got, (q, ans, src) in zip(body, expected):
    need(len(got) == 4, "key numbers row must have 4 cells: %r" % (got,))
    need(flat(got[0]) == q,
         "the questions must appear in the order given, verbatim:\n"
         "  expected %r\n  got      %r" % (q, flat(got[0])))
    need(got[1] == ans,
         "%r: answer must be %r as the source prints it, got %r" % (q, ans, got[1]))
    need(got[2] == src,
         "%r: the answer is stated in %s, cited as %r" % (q, src, got[2]))
    m = re.fullmatch(r"(\d+)(?:-(\d+))?", got[3])
    need(m, "Lines must be a line number or a range like 11-13, got %r" % got[3])
    a = int(m.group(1))
    b = int(m.group(2)) if m.group(2) else a
    text = source_span(got[2], a, b)
    pat = r"(?<![0-9.])" + re.escape(ans) + r"(?![0-9.])"
    need(re.search(pat, text),
         "%s lines %d-%d do not state %r; they read: %r"
         % (got[2], a, b, ans, text[:160]))

print("ok")
