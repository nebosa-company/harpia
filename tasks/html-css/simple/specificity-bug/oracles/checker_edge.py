import _webcheck as W

c = W.Check("specificity-bug/edge")
sheet = W.Sheet("styles.css")

# --- the tint utility no longer reaches into the banner ------------------
reach = [
    sel for _, sel, _ in sheet.rules
    if W.sel_has_class(sel, "section--tinted")
    and (W.sel_has_class(sel, "promo") or W.sel_has_class(sel, "promo__text"))
]
c.eq(reach, [], "no selector combines .section--tinted with the promo banner")

# --- no specificity was bought with !important ---------------------------
c.eq([(s, p) for s, p, _ in sheet.uses_important()], [], "no !important anywhere")

# --- ids were not used to win the cascade either --------------------------
id_sels = [sel for _, sel, _ in sheet.rules if "#" in sel]
c.eq(id_sels, [], "no id selectors were introduced")

# --- tokens are unchanged -------------------------------------------------
root = sheet.decls_for(":root")
for name, value in (
    ("--promo-bg", "#8a1220"),
    ("--promo-fg", "#fff5f0"),
    ("--accent", "#0b6cf5"),
    ("--ink", "#171b22"),
    ("--paper", "#ffffff"),
    ("--tint", "#f2f5fa"),
):
    c.eq(root.get(name), value, "%s keeps its value" % name)

# --- the markup was not touched ------------------------------------------
doc = W.parse_html("pricing.html")
links = doc.find_all("a", cls="nav__link")
c.eq(len(links), 4, "four nav links")
active = doc.find_all("a", cls="nav__link--active")
c.eq(len(active), 1, "exactly one active nav link")
if active:
    c.eq(active[0].attr("aria-current"), "page", "the active link keeps aria-current=page")
    c.eq(active[0].attr("href"), "/pricing", "the active link still points at /pricing")

tinted = doc.find_all(cls="section--tinted")
c.eq(len(tinted), 1, "one tinted section")
if tinted:
    c.eq(len(tinted[0].find_all(cls="promo")), 1, "the promo banner is still inside it")
    c.eq(len(tinted[0].find_all(cls="promo__text")), 1, "the promo text is still inside it")
    c.eq(len(tinted[0].find_all(cls="note")), 1, "the small print is still inside it")

c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes were added")

c.done()
