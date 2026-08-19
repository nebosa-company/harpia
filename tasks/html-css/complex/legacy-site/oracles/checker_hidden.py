import re

import _webcheck as W

c = W.Check("legacy-site/core")
sheet = W.Sheet("css/site.css")
c.ok(sheet.exists(), "css/site.css is present")

# --- bug 1: the area map and the track lists must agree ------------------
groups = {}
for ctx, sel, body in sheet.rules:
    if not W.sel_has_class(sel, "site-grid"):
        continue
    if re.search(r"[ >+~:\[]", sel):
        continue
    groups.setdefault(tuple(ctx), {}).update(W.declarations(body))

mapped = {k: v for k, v in groups.items() if v.get("grid-template-areas")}
c.ok(mapped, ".site-grid declares a named area map")
for ctx, decls in sorted(mapped.items()):
    where = " / ".join(ctx) if ctx else "top level"
    rows = W.areas(decls.get("grid-template-areas"))
    widths = sorted(set(len(r) for r in rows))
    c.eq(widths, [len(rows[0])] if rows else [], "%s: the area map is rectangular" % where)
    cols = decls.get("grid-template-columns")
    trows = decls.get("grid-template-rows")
    if c.ok(cols is not None, "%s: grid-template-columns is declared beside the areas" % where):
        c.eq(
            W.tracks(cols),
            len(rows[0]) if rows else 0,
            "%s: one column track per area column (%r)" % (where, cols),
        )
    if c.ok(trows is not None, "%s: grid-template-rows is declared beside the areas" % where):
        c.eq(
            W.tracks(trows),
            len(rows),
            "%s: one row track per area row (%r)" % (where, trows),
        )
    for name in ("main", "aside", "notes"):
        c.ok(
            any(name in row for row in rows),
            "%s: the area map still places %s" % (where, name),
        )

for name in ("main", "aside", "notes"):
    c.eq(
        W.squash(sheet.base("site-grid__%s" % name).get("grid-area")),
        name,
        ".site-grid__%s claims its area" % name,
    )

# --- bug 2: boxes fit inside their container -----------------------------
reset = [
    sel for sel, decls in sheet.all_rules("ANY")
    if sel.strip() == "*" and decls.get("box-sizing") == "border-box"
]
c.ok(reset, "the universal border-box reset is declared")

container = sheet.base("container")
c.eq(container.get("width"), "100%", ".container is full width")
c.ok(W.same(container.get("max-width"), "72rem"), ".container max-width kept -- got %r" % container.get("max-width"))
centred = (
    W.squash(container.get("margin-inline") or "") == "auto"
    or W.squash(container.get("margin") or "").endswith("auto")
    or W.squash(container.get("margin-left") or "") == "auto"
)
c.ok(centred, ".container is centred -- margin %r / margin-inline %r" % (container.get("margin"), container.get("margin-inline")))
c.ok(container.get("padding"), ".container keeps its horizontal padding")

# --- bug 3: one direction of breakpoint only -----------------------------
conditions = sheet.conditions()
c.eq(
    [cond for cond in conditions if "max-width" in W.squash(cond)],
    [],
    "the stylesheet is mobile first: no max-width media query",
)
c.ok(
    [cond for cond in conditions if "min-width" in W.squash(cond)],
    "the wide layout is expressed with a min-width query",
)
c.ok(
    any("48rem" in W.squash(cond) for cond in conditions),
    "the 48rem breakpoint is still where the layout changes",
)

# --- the single-column layout is the base, not the exception -------------
base = sheet.base("site-grid")
base_rows = W.areas(base.get("grid-template-areas"))
c.ok(base_rows, "the top-level .site-grid rule declares the area map")
if base_rows:
    c.eq(
        sorted(set(len(r) for r in base_rows)),
        [1],
        "the base layout is a single column",
    )

c.done()
