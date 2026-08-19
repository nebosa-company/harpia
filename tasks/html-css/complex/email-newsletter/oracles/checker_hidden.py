import _webcheck as W

c = W.Check("email-newsletter/core")
raw = W.read("newsletter.html")
doc = W.parse_html("newsletter.html")

# --- the document type email clients expect ------------------------------
head = raw[:400].lower()
c.ok("<!doctype" in head, "the file opens with a doctype")
c.ok(
    "xhtml 1.0 transitional" in head,
    "the XHTML 1.0 Transitional doctype is declared",
)
html = doc.find("html")
c.ok(html is not None and html.attr("lang") == "en", "<html lang=en>")
c.ok(
    html is not None and html.attr("xmlns") == "http://www.w3.org/1999/xhtml",
    "the xhtml namespace is declared",
)

# --- nothing an email client will drop on the floor ----------------------
c.eq(len(doc.find_all("script")), 0, "no <script> element")
c.eq(
    [n.attr("href") for n in doc.find_all("link") if (n.attr("rel") or "").lower() == "stylesheet"],
    [],
    "no external stylesheet",
)
styles = doc.find_all("style")
c.eq(len(styles), 1, "exactly one <style> block")

# --- table skeleton -------------------------------------------------------
tables = doc.find_all("table")
c.ok(len(tables) >= 3, "the layout is built from nested tables -- found %d" % len(tables))
for i, table in enumerate(tables):
    label = "table %d" % (i + 1)
    c.eq(table.attr("role"), "presentation", "%s carries role=presentation" % label)
    c.eq(table.attr("cellpadding"), "0", "%s cellpadding=0" % label)
    c.eq(table.attr("cellspacing"), "0", "%s cellspacing=0" % label)
    c.eq(table.attr("border"), "0", "%s border=0" % label)

outer = tables[0] if tables else None
c.ok(outer is not None and outer.attr("width") == "100%", "the outer table is full width")
c.ok(
    any(t.attr("width") == "600" for t in tables),
    "a content table is pinned to width=600",
)

# --- the two-column section stacks on narrow clients ---------------------
stacked = [n for n in doc.find_all("td") if n.has_class("stack")]
c.eq(len(stacked), 2, "the two-column section uses two td.stack cells")
c.eq(
    [n.attr("valign") for n in stacked],
    ["top", "top"],
    "both stacking cells are top aligned",
)
c.eq(
    [n.attr("width") for n in stacked],
    ["50%", "50%"],
    "both stacking cells declare width=50%",
)

style = styles[0] if styles else None
css = W.strip_comments(style.text() if style is not None else "")
media = [
    (ctx, sel, W.declarations(bodytext))
    for ctx, sel, bodytext in W.rules(css)
    if ctx
]
c.ok(media, "the <style> block holds a media query")
hits = [
    (ctx, sel, decls) for ctx, sel, decls in media
    if W.sel_has_class(sel, "stack")
    and any("max-width:600px" in W.squash(cond) for cond in ctx)
]
if c.ok(hits, "the media query restyles .stack at 600px"):
    _, _, decls = hits[0]
    c.ok(
        "block!important" in W.squash(decls.get("display") or ""),
        ".stack becomes display: block !important -- got %r" % decls.get("display"),
    )
    c.ok(
        "100%!important" in W.squash(decls.get("width") or ""),
        ".stack becomes width: 100%% !important -- got %r" % decls.get("width"),
    )

# --- the mail merge placeholders survive ---------------------------------
page = doc.stext()
c.ok("{{first_name}}" in page, "the greeting keeps the {{first_name}} placeholder")
unsub = [n for n in doc.find_all("a") if n.stext() == "Unsubscribe"]
if c.eq(len(unsub), 1, "one Unsubscribe link"):
    c.ok(
        "{{unsubscribe_url}}" in (unsub[0].attr("href") or ""),
        "the unsubscribe link keeps its placeholder -- got %r" % unsub[0].attr("href"),
    )

c.done()
