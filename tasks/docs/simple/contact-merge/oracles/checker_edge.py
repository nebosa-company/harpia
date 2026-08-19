"""Edge checks: dedupe, normalisation, precedence, dropped rows."""
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


need(os.path.isfile("contacts_master.csv"), "missing file: contacts_master.csv")
with open("contacts_master.csv", encoding="utf-8", newline="") as fh:
    rows = [[c.strip() for c in r] for r in csv.reader(fh) if any(c.strip() for c in r)]
need(len(rows) >= 2, "contacts_master.csv has no data rows")
body = [r for r in rows[1:] if len(r) == 5]
need(len(body) == len(rows) - 1, "every data row must have exactly 5 fields")

emails = [r[0] for r in body]
need(len(set(emails)) == len(emails),
     "duplicate email in the merged list: %r" % ([e for e in emails if emails.count(e) > 1],))
need(emails == sorted(emails), "rows must be sorted by email ascending")
for e in emails:
    need(e == e.lower(), "emails must be lower-cased, got %r" % e)
    need(e == e.strip() and " " not in e, "emails must be trimmed, got %r" % e)

# the events row with no email address is dropped, not carried as a blank
need(all(e for e in emails), "a row with no email address was kept")
need(not any("walk-in" in r[1].lower() for r in body),
     "the events sign-up row without an email address must be dropped")

# newsletter "Last, First" names are rewritten as "First Last"
by_email = {r[0]: r for r in body}
need("i.brandt@sable.example" in by_email, "missing newsletter-only contact i.brandt")
need(by_email["i.brandt@sable.example"][1] == "Ingo Brandt",
     "newsletter names must be rewritten as 'First Last', got %r"
     % by_email["i.brandt@sable.example"][1])
for r in body:
    need("," not in r[1], "full_name must not keep the 'Last, First' form: %r" % r[1])

# source precedence: CRM wins for name and company where it has the contact
need(by_email["ada.lovelace@northwind.example"][2] == "Northwind Analytics",
     "company must come from the highest-precedence source that has the contact")
need(by_email["e.nakamura@northwind.example"][2] == "Northwind Analytics",
     "the newsletter company value must not override the CRM one")
# phone falls through to a lower-precedence source when the winner has none
need(by_email["b.kaur@haldenmarine.example"][3] == "+47 51 22 90 30",
     "phone must fall through to the next source when the winning one is blank")

allowed = ["crm", "events", "newsletter"]
for r in body:
    parts = r[4].split(";")
    need(all(p in allowed for p in parts),
         "sources must be drawn from crm/events/newsletter, got %r" % r[4])
    need(parts == sorted(set(parts)),
         "sources must be alphabetical and de-duplicated, got %r" % r[4])

need(sum(1 for r in body if "crm" in r[4].split(";")) == 5,
     "five contacts come from the CRM export")
need(sum(1 for r in body if "events" in r[4].split(";")) == 5,
     "five contacts come from the events sign-up sheet")
need(sum(1 for r in body if "newsletter" in r[4].split(";")) == 5,
     "five contacts come from the newsletter list")

print("ok")
