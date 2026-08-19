import _webcheck as W

c = W.Check("grid-dashboard/core")
sheet = W.Sheet("dashboard.css")

shell = sheet.base("dashboard")
c.eq(shell.get("display"), "grid", ".dashboard is a grid container")
c.eq(
    W.areas(shell.get("grid-template-areas")),
    [["brand", "topbar"], ["sidenav", "main"], ["sidenav", "footer"]],
    "grid-template-areas matches the wireframe",
)
c.ok(
    W.same(shell.get("grid-template-columns"), "16rem 1fr"),
    "grid-template-columns -- got %r" % shell.get("grid-template-columns"),
)
c.ok(
    W.same(shell.get("grid-template-rows"), "4rem 1fr auto"),
    "grid-template-rows -- got %r" % shell.get("grid-template-rows"),
)
c.ok(W.same(shell.get("gap"), "1rem"), "gap is 1rem -- got %r" % shell.get("gap"))
c.ok(
    W.squash(shell.get("min-height")) in ("100vh", "100dvh"),
    "the shell fills the viewport -- got %r" % shell.get("min-height"),
)

# --- the track list agrees with the area map -----------------------------
rows = W.areas(shell.get("grid-template-areas"))
if rows:
    widths = sorted(set(len(r) for r in rows))
    c.eq(widths, [len(rows[0])], "every area row names the same number of columns")
    c.eq(
        W.tracks(shell.get("grid-template-columns")),
        len(rows[0]),
        "the column track list has one entry per area column",
    )
    c.eq(
        W.tracks(shell.get("grid-template-rows")),
        len(rows),
        "the row track list has one entry per area row",
    )

# --- every child claims its area -----------------------------------------
for name in ("brand", "topbar", "sidenav", "main", "footer"):
    decls = sheet.base("dashboard__%s" % name)
    c.eq(
        W.squash(decls.get("grid-area")),
        name,
        ".dashboard__%s claims grid-area: %s" % (name, name),
    )

c.done()
