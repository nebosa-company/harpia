"""Edge checks: requirements are grounded in their criterion, ids well formed."""
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


def load_backlog():
    text = read(os.path.join("stories", "backlog.md"))
    stories, cur = [], None
    in_ac = False
    for raw in text.split("\n"):
        s = raw.strip()
        m = re.match(r"^## (US-\d\d):", s)
        if m:
            cur = {"id": m.group(1), "status": None, "criteria": []}
            stories.append(cur)
            in_ac = False
            continue
        if cur is None:
            continue
        if s.lower().startswith("status:"):
            cur["status"] = s.split(":", 1)[1].strip().lower()
        elif s.lower().startswith("acceptance criteria"):
            in_ac = True
        elif in_ac and s.startswith("- "):
            cur["criteria"].append(s[2:].strip())
        elif in_ac and s and not s.startswith("- "):
            in_ac = False
    return stories


criteria = []
for s in load_backlog():
    if s["status"] == "accepted":
        criteria.extend(s["criteria"])

doc = read("SPEC.md")
lines = [l.rstrip() for l in doc.split("\n")]

reqs, cur = [], None
for l in lines:
    s = l.strip()
    if s.startswith("### "):
        cur = {"id": s[4:].strip(), "text": []}
        reqs.append(cur)
    elif cur is not None and s.startswith("Source:"):
        continue
    elif cur is not None and s and not s.startswith("|") and not s.startswith("#"):
        cur["text"].append(s)

need(len(reqs) == len(criteria),
     "expected %d requirements, got %d" % (len(criteria), len(reqs)))

for r in reqs:
    need(re.fullmatch(r"R-\d{3}", r["id"]),
         "requirement ids are R- plus three digits, got %r" % r["id"])

for r, crit in zip(reqs, criteria):
    text = " ".join(r["text"]).lower()
    need(len(text.split()) >= 5,
         "%s is too short to be a requirement: %r" % (r["id"], text))
    for num in re.findall(r"\d+", crit):
        need(num in text,
             "%s drops the figure %s from its criterion %r" % (r["id"], num, crit))
    words = [w for w in re.findall(r"[a-z]+", crit.lower()) if len(w) >= 6]
    if words:
        kept = sum(1 for w in words if w[:5] in text)
        need(kept * 2 >= len(words),
             "%s does not restate its criterion %r (kept %d of %d key words)"
             % (r["id"], crit, kept, len(words)))

# nothing from the rejected stories leaked in
low = doc.lower()
for phrase in ["batch print", "calendar month", "multi-currency", "conversion fee",
               "reporting currency", "single pdf"]:
    need(phrase not in low,
         "%r comes from a rejected story and must not be specified" % phrase)

# requirement ids are unique and referenced consistently
ids = [r["id"] for r in reqs]
need(len(set(ids)) == len(ids), "duplicate requirement id in the document")
for m in set(re.findall(r"R-\d{3}", doc)):
    need(m in ids, "the document references %s, which has no requirement" % m)

print("ok")
