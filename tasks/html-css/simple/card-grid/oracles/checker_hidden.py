import _webcheck as W

c = W.Check("card-grid/core")
sheet = W.Sheet("grid.css")
c.ok(sheet.exists(), "grid.css is present and not empty")

grid = sheet.for_class("card-grid")
c.eq(grid.get("display"), "grid", ".card-grid uses display: grid")
c.ok(
    W.same(grid.get("grid-template-columns"), "repeat(auto-fill, minmax(16rem, 1fr))"),
    ".card-grid grid-template-columns -- got %r" % grid.get("grid-template-columns"),
)
c.ok(W.same(grid.get("gap"), "1.5rem"), ".card-grid gap is 1.5rem -- got %r" % grid.get("gap"))
c.eq(grid.get("list-style"), "none", ".card-grid list marker is removed")
c.eq(grid.get("padding"), "0", ".card-grid padding is reset")
c.eq(grid.get("margin"), "0", ".card-grid margin is reset")

card = sheet.for_class("card")
c.eq(card.get("display"), "flex", ".card is a flex container")
c.eq(card.get("flex-direction"), "column", ".card stacks its children")

body = sheet.for_class("card__body")
c.ok(
    (body.get("flex") or "").split()[0:1] == ["1"] or body.get("flex-grow") == "1",
    ".card__body grows to fill the card -- got flex: %r" % body.get("flex"),
)

c.done()
