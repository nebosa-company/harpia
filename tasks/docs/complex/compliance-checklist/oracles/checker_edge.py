"""Edge checks: withdrawals, coverage counts, and the control gap analysis."""
import csv
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
            cur = {"id": m.group(1), "fields": {}, "area": meta.get("area")}
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
active = sorted((p for p in policies if "Withdrawn" not in p["fields"]),
                key=lambda p: p["id"])
withdrawn = sorted((p for p in policies if "Withdrawn" in p["fields"]),
                   key=lambda p: p["id"])

controls = []
with open("controls.csv", encoding="utf-8", newline="") as fh:
    for row in csv.DictReader(fh):
        controls.append((row["control_id"].strip(), row["control_name"].strip()))
covered = set()
for p in active:
    for c in p["fields"].get("Controls", "").split(","):
        if c.strip():
            covered.add(c.strip())
uncovered = [(cid, name) for cid, name in controls if cid not in covered]

doc = read("CHECKLIST.md")
lines = [l.rstrip() for l in doc.split("\n")]


def section(heading):
    idx = next((i for i, l in enumerate(lines) if l.strip() == heading), None)
    need(idx is not None, "missing heading: " + heading)
    out = []
    for l in lines[idx + 1:]:
        if l.strip().startswith("## "):
            break
        out.append(l.strip())
    return out


# withdrawn bullets
bullets = [l[2:].strip() for l in section("## Withdrawn") if l.startswith("- ")]
want_bullets = []
for p in withdrawn:
    m = re.search(r"superseded by ([A-Z]{3}-\d{2})", p["fields"]["Withdrawn"])
    need(m, "policy %s has no superseding id in its Withdrawn line" % p["id"])
    want_bullets.append("%s (superseded by %s)" % (p["id"], m.group(1)))
need(bullets == want_bullets,
     "the Withdrawn list is wrong:\n  expected %r\n  got      %r"
     % (want_bullets, bullets))

# coverage table
rows = []
for l in section("## Coverage"):
    if l.startswith("|"):
        cells = [c.strip() for c in l.strip("|").split("|")]
        if not all(c and set(c) <= set("-: ") for c in cells):
            rows.append(cells)
need(rows, "no table under ## Coverage")
need(rows[0] == ["Area", "Active", "Withdrawn"],
     "the coverage header must be | Area | Active | Withdrawn |, got %r" % (rows[0],))
areas = sorted({p["area"] for p in policies})
want_rows = [[a,
              str(sum(1 for p in active if p["area"] == a)),
              str(sum(1 for p in withdrawn if p["area"] == a))]
             for a in areas]
want_rows.append(["All areas", str(len(active)), str(len(withdrawn))])
need(rows[1:] == want_rows,
     "the coverage table is wrong:\n  expected %r\n  got      %r"
     % (want_rows, rows[1:]))

# uncovered controls
gaps = [l[2:].strip() for l in section("## Uncovered controls") if l.startswith("- ")]
want_gaps = ["%s %s" % (cid, name) for cid, name in uncovered]
need(gaps == want_gaps,
     "the control gaps are wrong:\n  expected %r\n  got      %r"
     % (want_gaps, gaps))
need(len(want_gaps) == 3,
     "the catalogue should leave three controls uncovered; checker found %d"
     % len(want_gaps))

# a control claimed only by a withdrawn policy is still a gap
for p in withdrawn:
    for c in p["fields"].get("Controls", "").split(","):
        c = c.strip()
        if c and c not in covered:
            need(any(g.startswith(c + " ") for g in gaps),
                 "%s is claimed only by the withdrawn policy %s, so it is a gap"
                 % (c, p["id"]))

# no invented ids anywhere
known = {p["id"] for p in policies} | {c for c, _ in controls}
for token in set(re.findall(r"\b(?:[A-Z]{3}-\d{2}|C-\d{2})\b", doc)):
    need(token in known, "the checklist mentions %s, which does not exist" % token)

print("ok")
