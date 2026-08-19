"""Core checks: every active policy on the checklist, exactly once, correct."""
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


LABELS = ("Statement:", "Evidence:", "Controls:", "Withdrawn:")


def parse_policy_doc(path):
    lines = read(path).split("\n")
    meta, i = {}, 0
    if lines and lines[0].strip() == "---":
        i = 1
        while i < len(lines) and lines[i].strip() != "---":
            if ":" in lines[i]:
                k, v = lines[i].split(":", 1)
                meta[k.strip()] = v.strip()
            i += 1
        i += 1
    out, cur, label = [], None, None
    for l in lines[i:]:
        s = l.strip()
        m = re.match(r"^## ([A-Z]{3}-\d{2})\s+(.*)$", s)
        if m:
            cur = {"id": m.group(1), "fields": {}, "area": meta.get("area"),
                   "owner": meta.get("owner")}
            out.append(cur)
            label = None
            continue
        if cur is None:
            continue
        hit = next((x for x in LABELS if s.startswith(x)), None)
        if hit:
            label = hit[:-1]
            cur["fields"][label] = [s[len(hit):].strip()]
        elif label and s:
            cur["fields"][label].append(s)
    for p in out:
        for k in list(p["fields"]):
            p["fields"][k] = flat(" ".join(p["fields"][k]))
    return out


policies = []
for f in sorted(os.listdir("policies")):
    if f.endswith(".md"):
        policies.extend(parse_policy_doc(os.path.join("policies", f)))
need(policies, "no policies found under policies/")
active = sorted((p for p in policies if "Withdrawn" not in p["fields"]),
                key=lambda p: p["id"])
withdrawn = sorted((p for p in policies if "Withdrawn" in p["fields"]),
                   key=lambda p: p["id"])
need(active and withdrawn, "expected both active and withdrawn policies")

doc = read("CHECKLIST.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Compliance Checklist",
     "the file must open with '# Compliance Checklist', got " + repr(first))
want_sections = ["## Checklist", "## Withdrawn", "## Coverage",
                 "## Uncovered controls"]
got_sections = [l.strip() for l in lines if l.strip().startswith("## ")]
need(got_sections == want_sections,
     "sections must be exactly %r in order, got %r" % (want_sections, got_sections))


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


rows = table_under("## Checklist")
need(rows[0] == ["ID", "Area", "Requirement", "Evidence", "Owner"],
     "the checklist header must be | ID | Area | Requirement | Evidence | Owner |, "
     "got %r" % (rows[0],))
body = rows[1:]
need(len(body) == len(active),
     "there are %d live policies; the checklist has %d rows"
     % (len(active), len(body)))
for got, want in zip(body, active):
    need(len(got) == 5, "checklist row must have 5 cells: %r" % (got,))
    need(got[0] == want["id"],
         "rows must be sorted by policy id; expected %s here, got %s"
         % (want["id"], got[0]))
    need(got[1] == want["area"],
         "%s area must be %r, got %r" % (want["id"], want["area"], got[1]))
    need(flat(got[2]) == want["fields"]["Statement"],
         "%s requirement must be the policy's Statement, verbatim:\n"
         "  expected %r\n  got      %r"
         % (want["id"], want["fields"]["Statement"], flat(got[2])))
    need(flat(got[3]) == want["fields"]["Evidence"],
         "%s evidence must be the policy's Evidence line, verbatim:\n"
         "  expected %r\n  got      %r"
         % (want["id"], want["fields"]["Evidence"], flat(got[3])))
    need(got[4] == want["owner"],
         "%s owner must be %r, got %r" % (want["id"], want["owner"], got[4]))

for p in withdrawn:
    ids = [r[0] for r in body]
    need(p["id"] not in ids,
         "%s is withdrawn and must not appear on the checklist" % p["id"])

print("ok")
