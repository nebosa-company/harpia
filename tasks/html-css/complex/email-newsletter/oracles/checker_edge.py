import _webcheck as W

c = W.Check("email-newsletter/edge")
doc = W.parse_html("newsletter.html")
body = W.body_of(doc)

# --- preheader ------------------------------------------------------------
first = body.children[0] if body.children else None
c.ok(first is not None and first.has_class("preheader"), "the preheader is the first element in <body>")
if first is not None:
    style = W.squash(first.attr("style") or "")
    c.ok("display:none" in style, "the preheader is hidden -- got %r" % first.attr("style"))
    c.ok("overflow:hidden" in style, "the preheader cannot leak into the layout")
    c.ok(first.stext().strip(), "the preheader carries a sentence")

# --- images ---------------------------------------------------------------
images = doc.find_all("img")
c.ok(len(images) >= 3, "the newsletter still shows its images -- found %d" % len(images))
for i, img in enumerate(images):
    label = "image %d" % (i + 1)
    c.ok(img.has_attr("alt"), "%s has an alt attribute" % label)
    c.ok((img.attr("width") or "").strip(), "%s declares a width attribute" % label)
    style = W.squash(img.attr("style") or "")
    c.ok("display:block" in style, "%s is display:block inline -- got %r" % (label, img.attr("style")))
    c.ok("border:0" in style, "%s suppresses the link border -- got %r" % (label, img.attr("style")))
c.eq([n.attr("src") for n in images if not (n.attr("src") or "").startswith("https://")], [], "every image src is absolute https")

# --- links ----------------------------------------------------------------
links = doc.find_all("a")
c.ok(len(links) >= 3, "the newsletter keeps its links")
bad = [
    n.attr("href") for n in links
    if not (n.attr("href") or "").startswith("https://")
    and "{{unsubscribe_url}}" not in (n.attr("href") or "")
]
c.eq(bad, [], "every link is an absolute https URL, apart from the merge placeholder")

# --- nothing an Outlook renderer cannot do -------------------------------
BANNED = ("display:flex", "display:grid", "position:", "float:")
offenders = []
for node in doc.walk():
    style = W.squash(node.attr("style") or "")
    for token in BANNED:
        if token in style:
            offenders.append((node.tag, token))
style_block = doc.find("style")
block_css = W.squash(style_block.text() if style_block is not None else "")
for token in BANNED:
    if token in block_css:
        offenders.append(("<style>", token))
c.eq(offenders, [], "no flexbox, grid, positioning or floats anywhere")

# --- styling is inline, not class based ----------------------------------
styled = W.inline_styled(doc)
c.ok(len(styled) >= 10, "the visual styling is inline -- only %d styled elements" % len(styled))
classed = sorted(set(name for n in doc.walk() for name in n.classes()))
c.eq(classed, ["preheader", "stack"], "the only classes used are preheader and stack")

# --- structure the ESP relies on -----------------------------------------
cells = [n for n in doc.find_all("td") if n.has_class("stack")]
if c.eq(len(cells), 2, "two stacking cells"):
    parent = cells[0].parent
    c.ok(parent is not None and parent.tag == "tr", "the stacking cells share one <tr>")
    c.ok(cells[1].parent is parent, "the stacking cells are siblings")

for cell in doc.find_all("td"):
    if cell.find_all("table"):
        continue
    if not cell.stext().strip():
        continue
    styles = [cell.attr("style") or ""] + [n.attr("style") or "" for n in cell.walk()]
    c.ok(
        any("font-family" in W.squash(s) for s in styles),
        "text cell %r declares a font-family inline" % cell.stext()[:36],
    )

c.eq(len(doc.find_all("body")), 1, "one <body>")
body_style = W.squash(body.attr("style") or "")
c.ok("margin:0" in body_style, "<body> zeroes its margin inline")
c.ok("background-color" in body_style, "<body> carries its background inline")

c.done()
