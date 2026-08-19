"""Core checks: every renewable account gets a correctly filled letter."""
import datetime
import json
import os
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


def normalise(text):
    ls = [l.rstrip() for l in text.split("\n")]
    while ls and not ls[0]:
        ls.pop(0)
    while ls and not ls[-1]:
        ls.pop()
    return "\n".join(ls)


MONTHS = ["January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December"]


def long_date(iso):
    d = datetime.date.fromisoformat(iso)
    return "%d %s %d" % (d.day, MONTHS[d.month - 1], d.year)


def money(value):
    return "EUR {:,.2f}".format(value)


template = read(os.path.join("template", "renewal-notice.md"))
accounts = json.loads(read(os.path.join("data", "accounts.json")))

REQUIRED = ["contact_name", "company", "address_line", "city", "postcode",
            "plan", "renewal_date", "seats", "unit_price", "account_manager"]

need(os.path.isdir("outbox"), "missing directory: outbox/")

wrote = 0
for acc in accounts:
    aid = acc["account_id"]
    missing = [k for k in REQUIRED
               if acc.get(k) is None or (isinstance(acc.get(k), str) and not acc[k].strip())]
    path = os.path.join("outbox", aid + ".md")
    if missing:
        continue
    wrote += 1
    got = normalise(read(path))
    renewal = datetime.date.fromisoformat(acc["renewal_date"])
    values = {
        "contact_name": acc["contact_name"],
        "contact_first_name": acc["contact_name"].split()[0],
        "company": acc["company"],
        "address_line": acc["address_line"],
        "city": acc["city"],
        "postcode": acc["postcode"],
        "plan": acc["plan"],
        "renewal_date": long_date(acc["renewal_date"]),
        "seats": str(acc["seats"]),
        "unit_price": money(acc["unit_price"]),
        "renewal_total": money(acc["seats"] * acc["unit_price"]),
        "change_deadline": long_date(
            (renewal - datetime.timedelta(days=14)).isoformat()),
        "account_manager": acc["account_manager"],
    }
    want = template
    for key, val in values.items():
        want = want.replace("{{" + key + "}}", val)
    want = normalise(want)
    if got != want:
        gl, wl = got.split("\n"), want.split("\n")
        for i in range(max(len(gl), len(wl))):
            g = gl[i] if i < len(gl) else "<end of file>"
            w = wl[i] if i < len(wl) else "<end of file>"
            if g != w:
                fail("outbox/%s.md line %d:\n  expected %r\n  got      %r"
                     % (aid, i + 1, w, g))
        fail("outbox/%s.md does not match the filled template" % aid)

need(wrote == 4, "expected 4 letters to be written, the checker found %d" % wrote)
print("ok")
