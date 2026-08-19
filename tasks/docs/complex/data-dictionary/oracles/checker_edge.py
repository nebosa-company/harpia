"""Edge checks: relationships, enumerations, undocumented columns."""
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


def parse_schema(path):
    text = read(path)
    tables = []
    for m in re.finditer(r"CREATE TABLE (\w+)\s*\((.*?)\n\);", text, re.S):
        name, body = m.group(1), m.group(2)
        cols, fks, enums = [], [], {}
        for raw in body.split("\n"):
            line = raw.strip().rstrip(",").strip()
            if not line or line.startswith("--"):
                continue
            up = line.upper()
            if up.startswith("FOREIGN KEY"):
                fm = re.match(r"FOREIGN KEY \((.*?)\) REFERENCES (\w+) \((.*?)\)", line)
                fks.append((fm.group(1).strip(), fm.group(2), fm.group(3).strip()))
                continue
            if up.startswith(("PRIMARY KEY", "UNIQUE", "CHECK", "CONSTRAINT")):
                continue
            toks = line.split()
            cname = toks[0]
            cm = re.search(r"CHECK\s*\(\s*%s\s+IN\s*\((.*?)\)\s*\)" % re.escape(cname),
                           line, re.I)
            if cm:
                enums[cname] = [v.strip().strip("'") for v in cm.group(1).split(",")]
            cols.append(cname)
        tables.append({"name": name, "columns": cols, "fks": fks, "enums": enums})
    return tables


def parse_notes(path):
    notes, cur = {}, None
    for l in read(path).split("\n"):
        s = l.strip()
        m = re.match(r"^## (\w+)$", s)
        if m:
            cur = m.group(1)
            notes[cur] = set()
            continue
        if cur and s.startswith("- ") and ":" in s:
            notes[cur].add(s[2:].split(":", 1)[0].strip())
    return notes


tables = parse_schema(os.path.join("schema", "schema.sql"))
notes = parse_notes(os.path.join("schema", "notes.md"))

doc = read("DATA_DICTIONARY.md")
lines = [l.rstrip() for l in doc.split("\n")]

want_sections = ["## Tables", "## Relationships", "## Enumerations",
                 "## Undocumented columns"]
got_sections = [l.strip() for l in lines
                if l.strip().startswith("## ") and not l.strip().startswith("### ")]
need(got_sections == want_sections,
     "sections must be exactly %r in order, got %r" % (want_sections, got_sections))


def bullets(heading):
    idx = next((i for i, l in enumerate(lines) if l.strip() == heading), None)
    need(idx is not None, "missing heading: " + heading)
    out = []
    for l in lines[idx + 1:]:
        s = l.strip()
        if s.startswith("## "):
            break
        if s.startswith("- "):
            out.append(s[2:].strip())
    return out


rels = []
for t in tables:
    for col, ptab, pcol in t["fks"]:
        rels.append("%s.%s -> %s.%s" % (t["name"], col, ptab, pcol))
want_rels = sorted(rels)
need(bullets("## Relationships") == want_rels,
     "relationships must list every foreign key, alphabetically:\n"
     "  expected %r\n  got      %r" % (want_rels, bullets("## Relationships")))

want_enums = []
for t in tables:
    for c in t["columns"]:
        if c in t["enums"]:
            want_enums.append("%s.%s: %s" % (t["name"], c, ", ".join(t["enums"][c])))
need(bullets("## Enumerations") == want_enums,
     "enumerations must list every CHECK ... IN column, in schema order, with the "
     "allowed values in the order declared:\n  expected %r\n  got      %r"
     % (want_enums, bullets("## Enumerations")))

want_undoc = sorted("%s.%s" % (t["name"], c) for t in tables for c in t["columns"]
                    if c not in notes.get(t["name"], set()))
need(bullets("## Undocumented columns") == want_undoc,
     "the undocumented list must name every column the notes do not cover, "
     "alphabetically:\n  expected %r\n  got      %r"
     % (want_undoc, bullets("## Undocumented columns")))
need(len(want_undoc) == 2,
     "the notes should leave two columns undocumented; checker found %d"
     % len(want_undoc))

# nothing invented: every dotted reference names a real column
known = {"%s.%s" % (t["name"], c) for t in tables for c in t["columns"]}
for token in set(re.findall(r"\b([a-z_]+\.[a-z_]+)\b", doc)):
    need(token in known,
         "the dictionary refers to %s, which is not a column in the schema" % token)

# a nullable column with an empty sample value is written (null), not blank
need("(null)" in doc,
     "a sample value that is empty must be written (null)")

print("ok")
