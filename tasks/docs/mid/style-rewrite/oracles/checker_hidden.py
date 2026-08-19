"""Core style rules: headings, line length, voice, product name."""
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


def prose(text):
    """The document with fenced blocks and inline code spans removed."""
    out, fenced = [], False
    for l in text.split("\n"):
        if l.strip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            out.append(re.sub(r"`[^`]*`", " ", l))
    return "\n".join(out)


def headings(text):
    out, fenced = [], False
    for l in text.split("\n"):
        if l.strip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced and re.match(r"^#{1,6} ", l.strip()):
            out.append(l.strip().lstrip("#").strip())
    return out


PROPER = {"kestrel", "sync", "windows", "macos", "linux", "python", "docker",
          "json", "yaml", "csv", "api", "cli", "ssh", "http"}

target = os.path.join("docs", "getting-started.md")
doc = read(target)
draft = read(os.path.join("draft", "getting-started.md"))
lines = doc.split("\n")
body = prose(doc)

# 1 - sentence case headings, wording preserved
got_h = headings(doc)
want_h = headings(draft)
key = lambda h: re.sub(r"[^a-z0-9]", "", h.lower())
need([key(h) for h in got_h] == [key(h) for h in want_h],
     "every heading from the draft must survive, in order and with the same "
     "wording:\n  draft %r\n  page  %r" % (want_h, got_h))
for h in got_h:
    words = [w for w in re.split(r"[\s/]+", h) if w]
    for w in words[1:]:
        bare = re.sub(r"[^A-Za-z0-9]", "", w)
        if bare and bare[0].isupper():
            need(bare.lower() in PROPER,
                 "heading %r is not in sentence case: %r is not a proper noun"
                 % (h, bare))

# 2 - line length
for i, l in enumerate(lines, 1):
    need(len(l) <= 80,
         "line %d is %d characters long (limit 80): %r" % (i, len(l), l[:60]))

# 3 - second person only
for word in ("we", "our", "us"):
    m = re.search(r"(?i)\b%s\b" % word, body)
    need(not m, "the page still says %r; address the reader as 'you'" % word)
need(not re.search(r"(?i)\bthe user\b", body),
     "the page still says 'the user'; address the reader as 'you'")

# 4 - no exclamation marks
need("!" not in body, "the page still contains an exclamation mark")

# 6 - product name
for m in re.findall(r"(?i)kestrel[-\s]*sync", body):
    need(m == "Kestrel Sync",
         "the product is written 'Kestrel Sync' outside code, got %r" % m)
need(not re.search(r"(?i)\bthe tool\b", body),
     "the page refers to 'the tool' instead of naming Kestrel Sync")
need("Kestrel Sync" in body, "the page never names Kestrel Sync")

print("ok")
