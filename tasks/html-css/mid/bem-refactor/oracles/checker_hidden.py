import _webcheck as W

c = W.Check("bem-refactor/core")
doc = W.parse_html("index.html")

blocks = doc.find_all("div", cls="media")
c.eq(len(blocks), 4, "four .media blocks")

EXPECT = [
    ("The quiet cost of a stale cache", "Ilona Fekete - 6 min", "/a/stale-cache", None),
    ("What a rollback actually restores", "Peter Aalto - 9 min", "/a/rollback", "media--featured"),
    ("Reading a flame graph without guessing", "Nadia Roche - 12 min", "/a/flame-graph", None),
    ("Three questions before adding an index", "Sam Ibarra - 4 min", "/a/index-questions", "media--compact"),
]

for i, block in enumerate(blocks[:4]):
    title, meta, href, modifier = EXPECT[i]
    label = "block %d" % (i + 1)

    figures = block.kids("figure", cls="media__figure")
    c.eq(len(figures), 1, "%s has one <figure class=media__figure>" % label)
    if figures:
        images = figures[0].find_all("img", cls="media__image")
        c.eq(len(images), 1, "%s figure holds one img.media__image" % label)

    bodies = block.kids("div", cls="media__body")
    c.eq(len(bodies), 1, "%s has one .media__body" % label)
    if bodies:
        body = bodies[0]
        titles = body.find_all("h3", cls="media__title")
        c.eq(len(titles), 1, "%s has one h3.media__title" % label)
        if titles:
            c.eq(titles[0].stext(), title, "%s title text" % label)
        metas = body.find_all("p", cls="media__meta")
        c.eq(len(metas), 1, "%s has one p.media__meta" % label)
        if metas:
            c.eq(metas[0].stext(), meta, "%s meta text" % label)
        links = body.find_all("a", cls="media__link")
        c.eq(len(links), 1, "%s has one a.media__link" % label)
        if links:
            c.eq(links[0].attr("href"), href, "%s link target" % label)

    if modifier:
        c.ok(block.has_class(modifier), "%s carries %s" % (label, modifier))
    else:
        c.eq(
            [m for m in block.classes() if m.startswith("media--")],
            [],
            "%s carries no modifier" % label,
        )

featured = doc.find_all(cls="media--featured")
compact = doc.find_all(cls="media--compact")
c.eq(len(featured), 1, "exactly one featured teaser")
c.eq(len(compact), 1, "exactly one compact teaser")
for node in featured + compact:
    c.ok(node.has_class("media"), "every modifier sits beside the block class")

# --- the old vocabulary is gone ------------------------------------------
OLD = ("card-wrap", "thumb", "thumb-img", "txt", "hdr", "sub", "feat", "tight", "more")
used = set()
for node in doc.walk():
    for name in node.classes():
        used.add(name)
c.eq(sorted(n for n in OLD if n in used), [], "no legacy class names remain in the markup")

c.done()
