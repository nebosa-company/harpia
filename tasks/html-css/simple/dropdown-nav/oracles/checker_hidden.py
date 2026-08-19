import _webcheck as W

c = W.Check("dropdown-nav/core")
doc = W.parse_html("index.html")
sheet = W.Sheet("nav.css")

nav = doc.find("nav", cls="site-nav")
if not c.ok(nav is not None, "<nav class=site-nav> exists"):
    c.done()
c.eq(nav.attr("aria-label"), "Primary", "nav aria-label")

menus = nav.find_all("ul", cls="menu")
c.eq(len(menus), 1, "one <ul class=menu>")
items = menus[0].kids("li") if menus else []
c.eq(len(items), 4, "four top-level items")

expect = [
    ("Home", "/", None),
    ("Products", "/products", "Products"),
    ("Support", "/support", "Support"),
    ("Contact", "/contact", None),
]
subs = {
    "Products": [
        ("Overview", "/products"),
        ("Pricing", "/products/pricing"),
        ("Changelog", "/products/changelog"),
    ],
    "Support": [
        ("Docs", "/support/docs"),
        ("Status", "/support/status"),
    ],
}

for i, item in enumerate(items[:4]):
    text, href, sub = expect[i]
    c.ok(item.has_class("menu__item"), "item %d has class menu__item" % (i + 1))
    links = item.kids("a")
    if c.eq(len(links), 1, "item %d has one top-level <a>" % (i + 1)):
        c.ok(links[0].has_class("menu__link"), "item %d link has class menu__link" % (i + 1))
        c.eq(links[0].attr("href"), href, "item %d href" % (i + 1))
        c.eq(links[0].stext(), text, "item %d text" % (i + 1))

    has_sub = item.has_class("menu__item--has-sub")
    c.eq(has_sub, sub is not None, "item %d modifier menu__item--has-sub" % (i + 1))

    panels = item.kids("ul")
    c.eq(len(panels), 1 if sub else 0, "item %d submenu count" % (i + 1))
    if sub and panels:
        panel = panels[0]
        c.ok(panel.has_class("submenu"), "%s submenu has class submenu" % sub)
        c.eq(panel.attr("aria-label"), sub, "%s submenu aria-label" % sub)
        rows = panel.kids("li")
        c.eq(len(rows), len(subs[sub]), "%s submenu item count" % sub)
        got = []
        for row in rows:
            anchors = row.kids("a")
            if anchors:
                got.append((anchors[0].stext(), anchors[0].attr("href")))
        c.eq(got, subs[sub], "%s submenu links, in order" % sub)

# --- the disclosure is declared in CSS, not script -----------------------
c.eq(len(doc.find_all("script")), 0, "no <script> element")

hidden = sheet.base("submenu")
c.eq(hidden.get("display"), "none", ".submenu is hidden by default")

hover = [
    r for r in sheet.rules_for_class("submenu")
    if ":hover" in r[1] and r[2].get("display") == "block"
]
c.ok(hover, "a :hover rule sets .submenu to display: block")

focus = [
    r for r in sheet.rules_for_class("submenu")
    if ":focus-within" in r[1] and r[2].get("display") == "block"
]
c.ok(focus, "a :focus-within rule sets .submenu to display: block")

c.done()
