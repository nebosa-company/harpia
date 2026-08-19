"""Edge rules: fences, contractions, list numbering, whitespace, facts kept."""
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
    out, fenced = [], False
    for l in text.split("\n"):
        if l.strip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            out.append(re.sub(r"`[^`]*`", " ", l))
    return "\n".join(out)


target = os.path.join("docs", "getting-started.md")
raw = read(target)
doc = raw.replace("\r\n", "\n")
lines = doc.split("\n")
body = prose(doc)

# 5 - every fence declares a language
opening = True
fence_count = 0
for i, l in enumerate(lines, 1):
    s = l.strip()
    if s.startswith("```"):
        if opening:
            fence_count += 1
            need(re.fullmatch(r"```[a-z0-9+-]+", s),
                 "line %d opens a code block without a language tag: %r" % (i, s))
        opening = not opening
need(opening, "a fenced code block is never closed")
need(fence_count >= 5,
     "the draft has five code blocks; the page has %d" % fence_count)

# 7 - no contractions
banned = ["don't", "doesn't", "didn't", "can't", "won't", "isn't", "aren't",
          "wasn't", "it's", "you're", "you'll", "you've", "we're", "let's",
          "that's", "there's"]
low = body.lower()
for c in banned:
    need(c not in low, "the page still contains the contraction %r" % c)
    need(c.replace("'", "’") not in low,
         "the page still contains the contraction %r" % c)

# 8 - ordered list items all use 1.
items = 0
for i, l in enumerate(lines, 1):
    m = re.match(r"^(\s*)(\d+)\.\s", l)
    if m:
        items += 1
        need(m.group(2) == "1",
             "line %d numbers an ordered list item %s.; every item is written "
             "1. : %r" % (i, m.group(2), l.strip()[:50]))
need(items >= 6, "the draft has six ordered list items; the page has %d" % items)

# 9 - whitespace
for i, l in enumerate(lines, 1):
    need(l == l.rstrip(), "line %d ends in whitespace" % i)
need(raw.endswith("\n") and not raw.endswith("\n\n"),
     "the file must end with exactly one newline")

# content survived the rewrite
for fact in ["pip install kestrel-sync", "kestrel --version",
             "~/.kestrel/config.yaml", "~/.kestrel/logs/sync.log",
             "kestrel sync run --profile nightly", "KESTREL_TOKEN",
             "HTTPS_PROXY", "~/.local/bin", "8443", "3.11", "401",
             "s3://kestrel-demo/nightly", "0 2 * * *"]:
    need(fact in doc, "the rewrite dropped %r, which the draft states" % fact)
need(re.search(r"\b5\b", doc), "the retry count of 5 is missing from the page")
need("%APPDATA%" in doc, "the Windows scripts path is missing from the page")

# the draft itself must still be there, untouched by the rewrite
need(os.path.isfile(os.path.join("draft", "getting-started.md")),
     "draft/getting-started.md must be left in place")

print("ok")
