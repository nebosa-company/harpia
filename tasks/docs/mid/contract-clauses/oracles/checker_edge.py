"""Edge checks: defined terms, cross references, and a clean object shape."""
import json
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


def parse_contract(text):
    sections, cur_sec, cur_cl = [], None, None
    for l in text.split("\n"):
        s = l.strip()
        m = re.match(r"^## (\d+)\.\s+(.+)$", s)
        if m:
            cur_sec = {"number": m.group(1), "clauses": []}
            sections.append(cur_sec)
            cur_cl = None
            continue
        m = re.match(r"^(\d+\.\d+)\s+(.*)$", s)
        if m and cur_sec is not None:
            cur_cl = {"id": m.group(1), "parts": [m.group(2)]}
            cur_sec["clauses"].append(cur_cl)
            continue
        if cur_cl is not None and s:
            cur_cl["parts"].append(s)
    out = {}
    for sec in sections:
        for cl in sec["clauses"]:
            body = re.sub(r"\s+", " ", " ".join(cl["parts"])).strip()
            terms, seen = [], set()
            for t in re.findall(r'"([^"]+)"\s+means', body):
                if t not in seen:
                    seen.add(t)
                    terms.append(t)
            refs, seen2 = [], set()
            for r in re.findall(r"Clause (\d+\.\d+)", body):
                if r not in seen2:
                    seen2.add(r)
                    refs.append(r)
            out[cl["id"]] = (terms, refs)
    return out


want = parse_contract(read(os.path.join("contract", "msa.md")))
doc = json.loads(read("clauses.json"))

got = {}
for sec in doc.get("sections", []):
    need(set(sec.keys()) == {"number", "title", "clauses"},
         "a section object must hold exactly number, title and clauses; got %r"
         % sorted(sec.keys()))
    for cl in sec.get("clauses", []):
        need(set(cl.keys()) == {"id", "text", "defined_terms", "cross_references"},
             "clause %s must hold exactly id, text, defined_terms and "
             "cross_references; got %r" % (cl.get("id"), sorted(cl.keys())))
        got[cl["id"]] = cl

need(set(got) == set(want),
     "clause ids do not match the agreement:\n  missing %r\n  extra   %r"
     % (sorted(set(want) - set(got)), sorted(set(got) - set(want))))

all_ids = set(want)
for cid, (terms, refs) in want.items():
    cl = got[cid]
    need(isinstance(cl["defined_terms"], list),
         "clause %s: defined_terms must be a list" % cid)
    need(cl["defined_terms"] == terms,
         "clause %s defined_terms:\n  expected %r\n  got      %r"
         % (cid, terms, cl["defined_terms"]))
    need(isinstance(cl["cross_references"], list),
         "clause %s: cross_references must be a list" % cid)
    need(cl["cross_references"] == refs,
         "clause %s cross_references:\n  expected %r\n  got      %r"
         % (cid, refs, cl["cross_references"]))
    for r in cl["cross_references"]:
        need(r in all_ids,
             "clause %s references %s, which is not a clause of this agreement"
             % (cid, r))
    need(cid not in cl["cross_references"],
         "clause %s must not reference itself" % cid)

defined = [t for cid in sorted(want) for t in want[cid][0]]
need(len(defined) == len(set(defined)),
     "the same term is recorded as defined more than once")
need(sum(len(v[0]) for v in want.values()) == 5,
     "the agreement defines five terms; the checker found %d"
     % sum(len(v[0]) for v in want.values()))

need(set(doc.keys()) == {"title", "sections"},
     "the top-level object must hold exactly title and sections; got %r"
     % sorted(doc.keys()))

print("ok")
