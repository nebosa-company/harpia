import _webcheck as W

c = W.Check("grid-dashboard/edge")
sheet = W.Sheet("dashboard.css")
doc = W.parse_html("dashboard.html")

# --- narrow viewport ------------------------------------------------------
narrow = "(max-width: 48rem)"
c.ok(sheet.has_condition(narrow), "a @media %s block exists" % narrow)
small = sheet.base("dashboard", cond=narrow)
c.eq(
    W.areas(small.get("grid-template-areas")),
    [["brand"], ["topbar"], ["main"], ["sidenav"], ["footer"]],
    "the narrow layout restacks the areas, main above sidenav",
)
c.eq(small.get("grid-template-columns"), "1fr", "the narrow layout is one column")
c.eq(
    W.tracks(small.get("grid-template-columns")), 1,
    "the narrow track list has exactly one column",
)
c.ok(small.get("grid-template-rows"), "the narrow layout restates its row tracks")

# --- layout comes from the grid, not from positioning --------------------
cheats = [
    (sel, prop, val) for sel, prop, val in sheet.values()
    if (prop == "float" and val != "none")
    or (prop == "position" and val in ("absolute", "fixed"))
]
c.eq(cheats, [], "no floats or absolute positioning are used for the shell")

# --- landmarks ------------------------------------------------------------
shell = doc.find(cls="dashboard")
if c.ok(shell is not None, "the .dashboard element is present"):
    for cls, tag in (
        ("dashboard__brand", "div"),
        ("dashboard__topbar", "header"),
        ("dashboard__sidenav", "nav"),
        ("dashboard__main", "main"),
        ("dashboard__footer", "footer"),
    ):
        nodes = shell.kids(tag, cls=cls)
        c.eq(len(nodes), 1, "one <%s class=%s>, a direct child of .dashboard" % (tag, cls))

nav = doc.find("nav", cls="dashboard__sidenav")
c.ok(nav is not None and nav.attr("aria-label") == "Sections", "the sidenav keeps its aria-label")
c.eq(len(doc.find_all("main")), 1, "exactly one <main>")
c.eq(len(doc.find_all("h1")), 1, "exactly one <h1>")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")

# --- the panels the app injects are untouched ----------------------------
panels = doc.find_all(cls="panel")
c.eq(
    [n.attr("id") for n in panels],
    ["panel-latency", "panel-errors", "panel-saturation"],
    "the application's panel ids are unchanged",
)

c.done()
