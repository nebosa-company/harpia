import _webcheck as W

c = W.Check("dropdown-nav/edge")
doc = W.parse_html("index.html")
sheet = W.Sheet("nav.css")

# --- positioning ----------------------------------------------------------
parent = sheet.base("menu__item--has-sub")
c.eq(parent.get("position"), "relative", ".menu__item--has-sub is the containing block")

panel = sheet.base("submenu")
c.eq(panel.get("position"), "absolute", ".submenu is absolutely positioned")
c.eq(panel.get("top"), "100%", ".submenu sits below its trigger")
c.eq(panel.get("left"), "0", ".submenu is left-aligned to its trigger")
c.ok(W.same(panel.get("min-width"), "12rem"), ".submenu min-width -- got %r" % panel.get("min-width"))
c.eq(panel.get("list-style"), "none", ".submenu drops its list markers")
c.eq(panel.get("margin"), "0", ".submenu margin is reset")

# --- keyboard visibility --------------------------------------------------
fv = [r for r in sheet.matching(":focus-visible") if r[2].get("outline")]
c.ok(fv, "a :focus-visible rule declares an outline")
bad = [r for r in fv if W.squash(r[2].get("outline")) in ("none", "0")]
c.eq([r[1] for r in bad], [], ":focus-visible outlines are visible, not none")

covered = set()
for _, sel, _ in fv:
    for name in W.sel_classes(sel):
        covered.add(name)
c.ok("menu__link" in covered, ".menu__link has a :focus-visible style")
c.ok("submenu__link" in covered, ".submenu__link has a :focus-visible style")

# --- no scripting escape hatch -------------------------------------------
handlers = []
for node in doc.walk():
    for key in node.attrs:
        if key.startswith("on"):
            handlers.append((node.tag, key))
c.eq(handlers, [], "no inline event-handler attributes")
c.eq(len(doc.find_all("script")), 0, "no <script> element")
c.eq(len(doc.find_all("button")), 0, "the trigger stays a link, not a button")

# --- every submenu link is a real link ------------------------------------
sub_links = doc.find_all("a", cls="submenu__link")
c.eq(len(sub_links), 5, "five submenu links in total")
c.eq([a.attr("href") for a in sub_links if not a.attr("href")], [], "every submenu link has an href")

items = doc.find_all("li", cls="menu__item--has-sub")
c.eq(len(items), 2, "exactly two items carry menu__item--has-sub")
for item in items:
    c.ok(item.has_class("menu__item"), "the modifier sits beside the block class")

c.done()
