import _webcheck as W

c = W.Check("print-stylesheet/core")
doc = W.parse_html("handbook.html")
sheet = W.Sheet("print.css")

c.ok(sheet.exists(), "print.css has rules in it")

# --- the sheet is loaded, for print only ---------------------------------
links = [n for n in doc.find_all("link") if (n.attr("rel") or "").lower() == "stylesheet"]
hrefs = [n.attr("href") for n in links]
c.eq(hrefs, ["screen.css", "print.css"], "screen.css then print.css, in that order")
printed = [n for n in links if n.attr("href") == "print.css"]
if c.eq(len(printed), 1, "print.css is linked exactly once"):
    c.eq(printed[0].attr("media"), "print", "print.css is linked with media=print")
screened = [n for n in links if n.attr("href") == "screen.css"]
if screened:
    c.ok(
        screened[0].attr("media") in (None, "screen", "all"),
        "the screen stylesheet keeps loading on screen",
    )

# --- page furniture is dropped -------------------------------------------
hidden = set()
for sel, decls in sheet.all_rules("ANY"):
    if decls.get("display") == "none":
        for name in W.sel_classes(sel):
            hidden.add(name)
for name in ("site-nav", "share-bar", "no-print"):
    c.ok(name in hidden, ".%s is set to display: none for print" % name)

# --- page box -------------------------------------------------------------
page = sheet.decls_for("@page")
c.ok(W.same(page.get("margin"), "2cm"), "@page margin is 2cm -- got %r" % page.get("margin"))

# --- link destinations survive the trip to paper -------------------------
expanded = [
    (sel, decls.get("content"))
    for sel, decls in sheet.all_rules("ANY")
    if "::after" in sel and "href^=" in W.squash(sel) and decls.get("content")
]
c.ok(expanded, "an a[href^=...]::after rule prints the destination")
c.ok(
    any("attr(href)" in W.squash(v) for _, v in expanded),
    "the printed destination comes from attr(href) -- got %r" % (expanded,),
)

c.done()
