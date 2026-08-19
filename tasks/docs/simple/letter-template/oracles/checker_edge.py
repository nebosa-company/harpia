"""Edge checks: incomplete accounts held back, nothing invented, no placeholders left."""
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


need(os.path.isdir("outbox"), "missing directory: outbox/")
files = sorted(f for f in os.listdir("outbox") if f.endswith(".md"))
need(files == ["ACC-1001.md", "ACC-1002.md", "ACC-1003.md", "ACC-1005.md",
               "SKIPPED.md"],
     "outbox/ must hold one letter per renewable account plus SKIPPED.md, got %r"
     % (files,))

for name in files:
    body = read(os.path.join("outbox", name))
    need("{{" not in body and "}}" not in body,
         "%s still contains an unfilled placeholder" % name)

# nothing invented for the held-back accounts
for name in ("ACC-1001.md", "ACC-1002.md", "ACC-1003.md", "ACC-1005.md"):
    body = read(os.path.join("outbox", name))
    need("Greta Halvorsen" not in body and "Ingo Brandt" not in body,
         "%s carries a contact from a held-back account" % name)

skipped = read(os.path.join("outbox", "SKIPPED.md"))
first = next((l.strip() for l in skipped.split("\n") if l.strip()), "")
need(first == "# Skipped accounts",
     "SKIPPED.md must open with '# Skipped accounts', got " + repr(first))
bullets = [l.strip()[2:].strip() for l in skipped.split("\n") if l.strip().startswith("- ")]
expect = ["ACC-1004 (missing: postcode)",
          "ACC-1006 (missing: account_manager, unit_price)"]
need(bullets == expect,
     "SKIPPED.md bullets wrong:\n  expected %r\n  got      %r" % (expect, bullets))

# the two held-back accounts must not have letters
for aid in ("ACC-1004", "ACC-1005x", "ACC-1006"):
    if aid in ("ACC-1004", "ACC-1006"):
        need(not os.path.exists(os.path.join("outbox", aid + ".md")),
             "%s has an incomplete record and must not get a letter" % aid)

# money and date formatting survived into the letters
one = read(os.path.join("outbox", "ACC-1003.md"))
need("EUR 14,250.00" in one,
     "ACC-1003 renewal total must read 'EUR 14,250.00'")
need("1 June 2026" in one, "ACC-1003 renewal date must read '1 June 2026'")
need("18 May 2026" in one,
     "ACC-1003 change deadline must be 14 days before renewal: '18 May 2026'")
need("2026-06-01" not in one, "dates must be rewritten in long form, not left as ISO")

two = read(os.path.join("outbox", "ACC-1002.md"))
need("EUR 740.00" in two, "ACC-1002 renewal total must read 'EUR 740.00'")
need("Dear Baljit," in two, "the salutation uses the contact's first name only")

print("ok")
