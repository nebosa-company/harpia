"""Core checks for contacts_master.csv."""
import csv
import os
import sys


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def need(cond, msg):
    if not cond:
        fail(msg)


need(os.path.isfile("contacts_master.csv"), "missing file: contacts_master.csv")
with open("contacts_master.csv", encoding="utf-8", newline="") as fh:
    rows = [[c.strip() for c in r] for r in csv.reader(fh) if any(c.strip() for c in r)]

need(rows, "contacts_master.csv is empty")
expect_header = ["email", "full_name", "company", "phone", "sources"]
need(rows[0] == expect_header,
     "header must be %s, got %s" % (",".join(expect_header), ",".join(rows[0])))

body = rows[1:]
expect = [
    ["ada.lovelace@northwind.example", "Ada Lovelace", "Northwind Analytics",
     "+44 20 7946 0102", "crm;events"],
    ["b.kaur@haldenmarine.example", "Baljit Kaur", "Halden Marine",
     "+47 51 22 90 30", "crm;newsletter"],
    ["c.moreau@castellane.example", "Camille Moreau", "Castellane Foods",
     "+33 1 70 18 22 09", "crm;events"],
    ["d.ericsson@ptarmiganrail.example", "Dag Ericsson", "Ptarmigan Rail",
     "+46 8 555 12 34", "crm"],
    ["e.nakamura@northwind.example", "Emi Nakamura", "Northwind Analytics",
     "+81 3 5555 0110", "crm;newsletter"],
    ["f.okonkwo@sable.example", "Femi Okonkwo", "Sable Logistics",
     "+234 1 271 0044", "events;newsletter"],
    ["g.halvorsen@ptarmiganrail.example", "Greta Halvorsen", "Ptarmigan Rail",
     "+47 22 44 11 90", "events"],
    ["h.silva@castellane.example", "Helena Silva", "Castellane Foods",
     "+351 21 999 8877", "events"],
    ["i.brandt@sable.example", "Ingo Brandt", "Sable Logistics",
     "", "newsletter"],
    ["j.almeida@castellane.example", "Joana Almeida", "Castellane Foods",
     "+351 21 444 2211", "newsletter"],
]
need(len(body) == len(expect),
     "expected %d merged contacts, got %d" % (len(expect), len(body)))
for got, want in zip(body, expect):
    need(len(got) == 5, "row must have 5 fields, got %d: %r" % (len(got), got))
    need(got[0] == want[0],
         "rows must be sorted by email ascending; expected %s here, got %s"
         % (want[0], got[0]))
    for col, g, w in zip(expect_header, got, want):
        need(g == w, "%s: column %s expected %r, got %r" % (want[0], col, w, g))

print("ok")
