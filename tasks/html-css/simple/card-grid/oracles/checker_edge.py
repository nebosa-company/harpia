import _webcheck as W

c = W.Check("card-grid/edge")
sheet = W.Sheet("grid.css")

# --- narrow viewport: one column -----------------------------------------
narrow = "(max-width: 40rem)"
c.ok(sheet.has_condition(narrow), "a @media %s block exists" % narrow)
small = sheet.for_class("card-grid", cond=narrow)
c.eq(small.get("grid-template-columns"), "1fr", ".card-grid is single column below 40rem")
c.ok(W.same(small.get("gap"), "1rem"), ".card-grid gap tightens to 1rem -- got %r" % small.get("gap"))

# --- wide viewport: four fixed tracks -------------------------------------
wide = "(min-width: 64rem)"
c.ok(sheet.has_condition(wide), "a @media %s block exists" % wide)
large = sheet.for_class("card-grid", cond=wide)
c.ok(
    W.same(large.get("grid-template-columns"), "repeat(4, 1fr)"),
    ".card-grid pins to four tracks at 64rem -- got %r" % large.get("grid-template-columns"),
)

# --- images ---------------------------------------------------------------
img = sheet.merged(".card__media img")
c.eq(img.get("display"), "block", ".card__media img is display: block")
c.eq(img.get("width"), "100%", ".card__media img fills its track")
c.eq(img.get("height"), "auto", ".card__media img height is auto")
c.ok(W.same(img.get("aspect-ratio"), "4 / 3"), ".card__media img aspect-ratio -- got %r" % img.get("aspect-ratio"))
c.eq(img.get("object-fit"), "cover", ".card__media img object-fit")

# --- no float layout anywhere --------------------------------------------
floats = [(s, p, v) for s, p, v in sheet.values() if p == "float"]
c.eq(floats, [], "no float declarations remain")
clears = [(s, p, v) for s, p, v in sheet.values() if p == "clear"]
c.eq(clears, [], "no clear declarations remain")
pct = [
    (s, v) for s, p, v in sheet.values()
    if p == "width" and W.sel_has_class(s, "card") and v.endswith("%") and v != "100%"
]
c.eq(pct, [], "no percentage width hacks on .card")

# --- the generated markup is untouched -----------------------------------
doc = W.parse_html("index.html")
grids = doc.find_all("ul", cls="card-grid")
c.eq(len(grids), 1, "one <ul class=card-grid>")
if grids:
    cards = grids[0].kids("li")
    c.eq(len(cards), 6, "six cards")
    for i, card in enumerate(cards):
        c.ok(card.has_class("card"), "card %d keeps its class" % (i + 1))
        c.eq(len(card.find_all(cls="card__media")), 1, "card %d has a media block" % (i + 1))
        c.eq(len(card.find_all(cls="card__body")), 1, "card %d has a body block" % (i + 1))
        c.eq(len(card.find_all(cls="card__footer")), 1, "card %d has a footer block" % (i + 1))

c.done()
