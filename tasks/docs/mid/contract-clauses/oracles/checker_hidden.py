"""Core checks: clauses.json mirrors the agreement's structure and text."""
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
    title, sections, cur_sec, cur_cl = None, [], None, None
    for l in text.split("\n"):
        s = l.strip()
        if title is None and s.startswith("# "):
            title = s[2:].strip()
            continue
        m = re.match(r"^## (\d+)\.\s+(.+)$", s)
        if m:
            cur_sec = {"number": m.group(1), "title": m.group(2).strip(), "clauses": []}
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
    for sec in sections:
        for cl in sec["clauses"]:
            cl["text"] = re.sub(r"\s+", " ", " ".join(cl.pop("parts"))).strip()
    return title, sections


title, sections = parse_contract(read(os.path.join("contract", "msa.md")))
need(title and sections, "could not read the agreement")

raw = read("clauses.json")
try:
    doc = json.loads(raw)
except Exception as exc:
    fail("clauses.json is not valid JSON: %s" % exc)

need(isinstance(doc, dict), "the top level of clauses.json must be an object")
need(doc.get("title") == title,
     "title must be %r, got %r" % (title, doc.get("title")))
need(isinstance(doc.get("sections"), list), "'sections' must be a list")

got_secs = doc["sections"]
need(len(got_secs) == len(sections),
     "expected %d sections, got %d" % (len(sections), len(got_secs)))
for gs, ws in zip(got_secs, sections):
    need(isinstance(gs, dict), "each section must be an object, got %r" % (gs,))
    need(gs.get("number") == ws["number"],
         "sections must run in document order; expected number %r, got %r"
         % (ws["number"], gs.get("number")))
    need(gs.get("title") == ws["title"],
         "section %s title must be %r, got %r"
         % (ws["number"], ws["title"], gs.get("title")))
    need(isinstance(gs.get("clauses"), list),
         "section %s needs a 'clauses' list" % ws["number"])
    need(len(gs["clauses"]) == len(ws["clauses"]),
         "section %s has %d clauses, got %d"
         % (ws["number"], len(ws["clauses"]), len(gs["clauses"])))
    for gc, wc in zip(gs["clauses"], ws["clauses"]):
        need(isinstance(gc, dict), "each clause must be an object, got %r" % (gc,))
        need(gc.get("id") == wc["id"],
             "clauses must run in document order; expected id %r, got %r"
             % (wc["id"], gc.get("id")))
        need(gc.get("text") == wc["text"],
             "clause %s text must be the clause body with the number removed and "
             "whitespace collapsed:\n  expected %r\n  got      %r"
             % (wc["id"], wc["text"], gc.get("text")))

print("ok")
