import _webcheck as W

c = W.Check("bem-refactor/edge")
doc = W.parse_html("index.html")
sheet = W.Sheet("teasers.css")

ALLOWED = {
    "page", "teasers",
    "media", "media--featured", "media--compact",
    "media__figure", "media__image", "media__body",
    "media__title", "media__meta", "media__link",
}

# --- the stylesheet speaks only the published vocabulary -----------------
strays = sorted(
    set(
        name
        for _, sel, _ in sheet.rules
        for name in W.sel_classes(sel)
        if name not in ALLOWED
    )
)
c.eq(strays, [], "teasers.css uses only the published class names")

# --- element classes stand on their own ----------------------------------
combined = [
    sel for _, sel, _ in sheet.rules
    if W.sel_has_class(sel, "media")
    and any(name.startswith("media__") for name in W.sel_classes(sel))
]
c.eq(
    combined, [],
    "no selector qualifies an element class with the block class",
)

# --- modifier overrides are scoped through the modifier ------------------
for modifier in ("media--featured", "media--compact"):
    hits = [
        sel for _, sel, _ in sheet.rules
        if W.sel_has_class(sel, modifier)
    ]
    c.ok(hits, ".%s has rules of its own" % modifier)

c.ok(
    any(
        W.sel_has_class(sel, "media--featured") and W.sel_has_class(sel, "media__title")
        for _, sel, _ in sheet.rules
    ),
    "the featured teaser still enlarges its title",
)
c.ok(
    any(
        W.sel_has_class(sel, "media--compact") and W.sel_has_class(sel, "media__title")
        for _, sel, _ in sheet.rules
    ),
    "the compact teaser still shrinks its title",
)
c.ok(
    W.same(sheet.base("media--compact").get("grid-template-columns"), "7rem 1fr"),
    "the compact modifier keeps its narrower figure column",
)
c.ok(
    W.same(sheet.base("media").get("grid-template-columns"), "12rem 1fr"),
    "the base block keeps its figure column",
)

# --- the raw text of the sheet carries no legacy names -------------------
OLD = ("card-wrap", "thumb-img", "thumb", "txt", "hdr", "sub", "feat", "tight", "more")
raw_hits = sorted(set(n for n in OLD if ("." + n) in sheet.raw))
c.eq(raw_hits, [], "no legacy class selectors remain in teasers.css")

# --- behaviour preserved --------------------------------------------------
c.eq(
    [n.attr("href") for n in doc.find_all("a")],
    ["/a/stale-cache", "/a/rollback", "/a/flame-graph", "/a/index-questions"],
    "link targets, in order",
)
c.eq(
    [n.attr("src") for n in doc.find_all("img")],
    ["img/cache.png", "img/rollback.png", "img/flame.png", "img/index.png"],
    "image sources, in order",
)
c.eq([n.attr("alt") for n in doc.find_all("img")], [""] * 4, "decorative images keep empty alt")
c.eq(len(doc.find_all("h3")), 4, "four teaser headings")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")
c.eq(len(doc.find_all("style")), 0, "no <style> block")

c.done()
