"""Core checks: every table and column documented, correctly, exactly once."""
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


def parse_schema(path):
    text = read(path)
    tables = []
    for m in re.finditer(r"CREATE TABLE (\w+)\s*\((.*?)\n\);", text, re.S):
        name, body = m.group(1), m.group(2)
        cols, pk, fks, enums = [], [], [], {}
        for raw in body.split("\n"):
            line = raw.strip().rstrip(",").strip()
            if not line or line.startswith("--"):
                continue
            up = line.upper()
            if up.startswith("PRIMARY KEY"):
                pk = [c.strip() for c in re.search(r"\((.*?)\)", line).group(1).split(",")]
                continue
            if up.startswith("FOREIGN KEY"):
                fm = re.match(r"FOREIGN KEY \((.*?)\) REFERENCES (\w+) \((.*?)\)", line)
                fks.append((fm.group(1).strip(), fm.group(2), fm.group(3).strip()))
                continue
            if up.startswith(("UNIQUE", "CHECK", "CONSTRAINT")):
                continue
            toks = line.split()
            cname, ctype = toks[0], toks[1]
            cm = re.search(r"CHECK\s*\(\s*%s\s+IN\s*\((.*?)\)\s*\)" % re.escape(cname),
                           line, re.I)
            if cm:
                enums[cname] = [v.strip().strip("'") for v in cm.group(1).split(",")]
            cols.append({"name": cname, "type": ctype, "notnull": "NOT NULL" in up})
        for c in cols:
            keys = []
            if c["name"] in pk:
                keys.append("PK")
            if any(c["name"] == f[0] for f in fks):
                keys.append("FK")
            c["key"] = ", ".join(keys)
            c["nullable"] = "no" if (c["notnull"] or c["name"] in pk) else "yes"
        tables.append({"name": name, "columns": cols, "fks": fks, "enums": enums})
    return tables


def parse_notes(path):
    notes, cur = {}, None
    lines = read(path).split("\n")
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        m = re.match(r"^## (\w+)$", s)
        if m:
            cur = m.group(1)
            notes[cur] = {}
            i += 1
            continue
        if cur and s.startswith("- ") and ":" in s:
            col, desc = s[2:].split(":", 1)
            parts, j = [desc.strip()], i + 1
            while j < len(lines):
                nxt = lines[j].strip()
                if not nxt or nxt.startswith("- ") or nxt.startswith("#"):
                    break
                parts.append(nxt)
                j += 1
            notes[cur][col.strip()] = flat(" ".join(parts))
            i = j
            continue
        i += 1
    return notes


tables = parse_schema(os.path.join("schema", "schema.sql"))
need(tables, "could not read schema/schema.sql")
notes = parse_notes(os.path.join("schema", "notes.md"))
samples = {}
for t in tables:
    with open(os.path.join("samples", t["name"] + ".csv"), encoding="utf-8",
              newline="") as fh:
        samples[t["name"]] = list(csv.DictReader(fh))[0]

doc = read("DATA_DICTIONARY.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Data Dictionary",
     "the file must open with '# Data Dictionary', got " + repr(first))

got_tables = [l.strip()[4:].strip() for l in lines if l.strip().startswith("### ")]
want_tables = [t["name"] for t in tables]
need(got_tables == want_tables,
     "one level-3 section per table, in schema order:\n  expected %r\n  got      %r"
     % (want_tables, got_tables))

blocks = {}
cur = None
for l in lines:
    s = l.strip()
    if s.startswith("### "):
        cur = s[4:].strip()
        blocks[cur] = []
    elif s.startswith("## "):
        cur = None
    elif cur is not None and s.startswith("|"):
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not all(c and set(c) <= set("-: ") for c in cells):
            blocks[cur].append(cells)

for t in tables:
    rows = blocks[t["name"]]
    need(rows, "table %s has no column table" % t["name"])
    need(rows[0] == ["Column", "Type", "Nullable", "Key", "Description", "Example"],
         "%s header must be | Column | Type | Nullable | Key | Description | Example |, "
         "got %r" % (t["name"], rows[0]))
    body = rows[1:]
    need(len(body) == len(t["columns"]),
         "%s has %d columns; the dictionary documents %d"
         % (t["name"], len(t["columns"]), len(body)))
    for got, c in zip(body, t["columns"]):
        need(len(got) == 6, "%s: row must have 6 cells: %r" % (t["name"], got))
        where = "%s.%s" % (t["name"], c["name"])
        need(got[0] == c["name"],
             "%s: columns must be in declaration order; expected %s, got %s"
             % (t["name"], c["name"], got[0]))
        need(got[1] == c["type"],
             "%s type must be %r as declared, got %r" % (where, c["type"], got[1]))
        need(got[2] == c["nullable"],
             "%s nullable must be %r, got %r" % (where, c["nullable"], got[2]))
        key = "" if got[3] in ("", "-") else got[3]
        need(key == c["key"],
             "%s key must be %r, got %r" % (where, c["key"], got[3]))
        desc = notes.get(t["name"], {}).get(c["name"])
        want_desc = desc if desc is not None else "(undocumented)"
        need(flat(got[4]) == want_desc,
             "%s description must be the note verbatim:\n  expected %r\n  got      %r"
             % (where, want_desc, flat(got[4])))
        val = samples[t["name"]].get(c["name"], "")
        want_ex = val if val else "(null)"
        need(got[5] == want_ex,
             "%s example must be the first sample row's value, %r, got %r"
             % (where, want_ex, got[5]))

print("ok")
