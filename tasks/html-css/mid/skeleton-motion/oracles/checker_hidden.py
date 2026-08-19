import _webcheck as W

c = W.Check("skeleton-motion/core")
doc = W.parse_html("feed.html")
sheet = W.Sheet("feed.css")

# --- markup ---------------------------------------------------------------
feed = doc.find("section", cls="feed")
if not c.ok(feed is not None, "the .feed section is present"):
    c.done()
c.eq(feed.attr("aria-live"), "polite", ".feed announces updates politely")
c.eq(feed.attr("aria-busy"), "true", ".feed is marked busy while it loads")

loading = doc.find_all("article", cls="card--loading")
c.eq(len(loading), 2, "two loading cards")
for i, card in enumerate(loading):
    label = "loading card %d" % (i + 1)
    c.ok(card.has_class("card"), "%s keeps the card block class" % label)

    notices = card.find_all("p", cls="visually-hidden")
    c.eq(len(notices), 1, "%s carries one .visually-hidden notice" % label)
    if notices:
        c.eq(notices[0].stext(), "Loading activity", "%s notice text" % label)

    bars = card.find_all("span", cls="skeleton")
    c.eq(len(bars), 4, "%s holds four .skeleton bars" % label)
    variants = [
        [v for v in n.classes() if v.startswith("skeleton--")] for n in bars
    ]
    c.eq(
        variants,
        [["skeleton--avatar"], ["skeleton--title"], ["skeleton--text"], ["skeleton--text"]],
        "%s bar variants, in order" % label,
    )
    c.eq(
        [n.attr("aria-hidden") for n in bars],
        ["true"] * 4,
        "%s bars are hidden from assistive tech" % label,
    )

real = [n for n in doc.find_all("article", cls="card") if not n.has_class("card--loading")]
c.eq(len(real), 1, "the loaded card is untouched")
if real:
    c.ok("Deploy 4f2a91 promoted" in real[0].stext(), "the loaded card keeps its copy")

# --- the shimmer ----------------------------------------------------------
skeleton = sheet.base("skeleton")
c.eq(skeleton.get("display"), "block", ".skeleton is a block box")
c.ok(
    W.same(skeleton.get("background-size"), "200% 100%"),
    ".skeleton background-size -- got %r" % skeleton.get("background-size"),
)
c.ok(
    "linear-gradient" in W.squash(skeleton.get("background-image") or skeleton.get("background") or ""),
    ".skeleton paints a linear-gradient sheen",
)
animation = skeleton.get("animation") or ""
c.ok("skeleton-shimmer" in animation, ".skeleton runs the skeleton-shimmer animation -- got %r" % animation)
c.ok("infinite" in animation, ".skeleton shimmer loops -- got %r" % animation)

frames = [
    (head, body) for head, body in sheet.at_rules("@keyframes")
    if "skeleton-shimmer" in head
]
if c.eq(len(frames), 1, "one @keyframes skeleton-shimmer block"):
    body = frames[0][1]
    c.ok(
        ("from" in body and "to" in body) or ("0%" in body and "100%" in body),
        "the keyframes declare a start and an end",
    )
    c.ok(
        body.count("background-position") >= 2,
        "the keyframes move background-position",
    )

c.done()
