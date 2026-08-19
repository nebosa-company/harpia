import re

import _webcheck as W

c = W.Check("fluid-type/edge")
sheet = W.Sheet("type.css")
root = sheet.decls_for(":root")

STEPS = ["--step--1", "--step-0", "--step-1", "--step-2", "--step-3", "--step-4"]
REM = re.compile(r"(-?\d+(?:\.\d+)?)rem")
VW = re.compile(r"(-?\d+(?:\.\d+)?)vw")

floors, ceilings, slopes = [], [], []
for name in STEPS:
    args = W.clamp_args(root.get(name))
    if args is None:
        c.ok(False, "%s parses as a clamp() with three arguments" % name)
        continue
    lo = W.rem(args[0])
    hi = W.rem(args[2])
    vws = VW.findall(args[1])
    if lo is None or hi is None or not vws:
        c.ok(False, "%s has a rem floor, a rem ceiling and a vw slope" % name)
        continue
    floors.append((name, lo))
    ceilings.append((name, hi))
    slopes.append((name, float(vws[0])))
    c.ok(hi > lo, "%s ceiling is above its floor (%s > %s)" % (name, hi, lo))

# --- the scale really is a scale -----------------------------------------
def increasing(pairs, label):
    for i in range(1, len(pairs)):
        c.ok(
            pairs[i][1] > pairs[i - 1][1],
            "%s: %s (%s) is above %s (%s)"
            % (label, pairs[i][0], pairs[i][1], pairs[i - 1][0], pairs[i - 1][1]),
        )


c.eq(len(floors), len(STEPS), "all six steps parsed")
increasing(floors, "floors rise with the scale")
increasing(ceilings, "ceilings rise with the scale")
increasing(slopes, "the viewport slope steepens with the scale")
c.eq([n for n, v in slopes if v <= 0], [], "every step actually interpolates (vw > 0)")

# --- the ends are where the brand team put them ---------------------------
by_name = dict(floors)
by_ceiling = dict(ceilings)
if "--step--1" in by_name:
    c.ok(
        0.75 <= by_name["--step--1"] <= 0.95,
        "--step--1 floor sits between 0.75rem and 0.95rem -- got %s" % by_name["--step--1"],
    )
if "--step-4" in by_ceiling:
    c.ok(
        3.0 <= by_ceiling["--step-4"] <= 4.5,
        "--step-4 ceiling sits between 3rem and 4.5rem -- got %s" % by_ceiling["--step-4"],
    )

# --- nothing steps at a breakpoint, nothing is pinned in pixels ----------
stepped = [
    (sel, val) for sel, prop, val in sheet.values()
    if prop == "font-size" and sel not in (":root",)
]
in_media = []
for ctx, sel, body in sheet.rules:
    if ctx and "font-size" in W.declarations(body):
        in_media.append((ctx, sel))
c.eq(in_media, [], "no font-size is set inside a media query")

pixel = [
    (sel, prop, val) for sel, prop, val in sheet.values()
    if prop in ("font-size",) or prop.startswith("--step")
]
c.eq(
    [(s, p, v) for s, p, v in pixel if "px" in v],
    [],
    "no font size is expressed in px",
)

# --- body leading is unitless --------------------------------------------
lh = sheet.merged("body").get("line-height")
c.ok(
    lh is not None and re.match(r"^\d+(\.\d+)?$", lh.strip()) is not None,
    "body line-height is a unitless ratio -- got %r" % lh,
)

# --- the specimen markup is untouched -------------------------------------
doc = W.parse_html("index.html")
c.eq(len(doc.find_all("h1")), 1, "one <h1>")
for tag in ("h2", "h3", "h4", "small"):
    c.ok(doc.find(tag) is not None, "the specimen still shows <%s>" % tag)
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")

c.done()
