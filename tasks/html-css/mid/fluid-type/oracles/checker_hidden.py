import re

import _webcheck as W

c = W.Check("fluid-type/core")
sheet = W.Sheet("type.css")
root = sheet.decls_for(":root")

STEPS = ["--step--1", "--step-0", "--step-1", "--step-2", "--step-3", "--step-4"]

REM = re.compile(r"(-?\d+(?:\.\d+)?)rem")
VW = re.compile(r"(-?\d+(?:\.\d+)?)vw")

parsed = {}
for name in STEPS:
    value = root.get(name)
    if not c.ok(value is not None, "%s is defined on :root" % name):
        continue
    args = W.clamp_args(value)
    if not c.ok(args is not None, "%s is a clamp() with three arguments -- got %r" % (name, value)):
        continue
    low, mid, high = args
    lo = W.rem(low)
    hi = W.rem(high)
    c.ok(lo is not None, "%s floor is a plain rem length -- got %r" % (name, low))
    c.ok(hi is not None, "%s ceiling is a plain rem length -- got %r" % (name, high))
    rems = REM.findall(mid)
    vws = VW.findall(mid)
    c.eq(len(rems), 1, "%s preferred value has exactly one rem term -- got %r" % (name, mid))
    c.eq(len(vws), 1, "%s preferred value has exactly one vw term -- got %r" % (name, mid))
    c.ok("+" in mid, "%s preferred value adds its rem and vw terms -- got %r" % (name, mid))
    if lo is not None and hi is not None and rems and vws:
        parsed[name] = (lo, hi, float(vws[0]), float(rems[0]))

# --- the anchor step ------------------------------------------------------
if "--step-0" in parsed:
    lo, hi, _, _ = parsed["--step-0"]
    c.eq(lo, 1.0, "--step-0 floor is 1rem")
    c.eq(hi, 1.25, "--step-0 ceiling is 1.25rem")

# --- usage ----------------------------------------------------------------
USAGE = [
    ("body", "--step-0"),
    ("h1", "--step-4"),
    ("h2", "--step-3"),
    ("h3", "--step-2"),
    ("h4", "--step-1"),
    ("small", "--step--1"),
]
for selector, step in USAGE:
    got = sheet.merged(selector).get("font-size")
    c.ok(
        got is not None and W.squash(got) == W.squash("var(%s)" % step),
        "%s uses var(%s) -- got %r" % (selector, step, got),
    )

c.done()
