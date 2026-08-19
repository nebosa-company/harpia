import _webcheck as W

c = W.Check("print-stylesheet/edge")
doc = W.parse_html("handbook.html")
sheet = W.Sheet("print.css")
screen = W.Sheet("screen.css")

# --- paper typography -----------------------------------------------------
body = sheet.merged("body")
c.eq(body.get("font-size"), "12pt", "body font-size is stated in points")
c.ok(W.squash(body.get("color")) in ("#000", "#000000", "black"), "body ink is black -- got %r" % body.get("color"))
c.ok(
    W.squash(body.get("background")) in ("#fff", "#ffffff", "white")
    or W.squash(body.get("background-color")) in ("#fff", "#ffffff", "white"),
    "body background is white -- got %r" % body.get("background"),
)

# --- pagination -----------------------------------------------------------
break_after = set()
break_inside = set()
for sel, decls in sheet.all_rules("ANY"):
    if decls.get("break-after") == "avoid" or decls.get("page-break-after") == "avoid":
        for tag in sel.replace(",", " ").split():
            break_after.add(tag.strip())
    if decls.get("break-inside") == "avoid" or decls.get("page-break-inside") == "avoid":
        for tag in sel.replace(",", " ").split():
            break_inside.add(tag.strip())
for tag in ("h2", "h3"):
    c.ok(tag in break_after, "%s does not end a page alone" % tag)
for tag in ("table", "figure", "pre"):
    c.ok(tag in break_inside, "%s is not split across pages" % tag)

para = sheet.merged("p")
c.eq(para.get("orphans"), "3", "paragraph orphans control")
c.eq(para.get("widows"), "3", "paragraph widows control")

img = sheet.merged("img")
c.eq(img.get("max-width"), "100%", "images are clamped to the page width")

# --- the no-print hook is actually applied -------------------------------
share = doc.find(cls="share-bar")
c.ok(share is not None and share.has_class("no-print"), "the share bar carries no-print")
top = doc.find(cls="to-top")
c.ok(top is not None and top.has_class("no-print"), "the back-to-top link carries no-print")

# --- screen styles untouched ---------------------------------------------
c.ok(screen.exists(), "screen.css is still there")
c.ok(
    W.same(screen.merged("main").get("max-width"), "44rem"),
    "screen.css was not edited",
)
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")
c.eq(len(doc.find_all("style")), 0, "no <style> block was added")

c.done()
