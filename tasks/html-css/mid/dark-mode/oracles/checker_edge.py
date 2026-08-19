import _webcheck as W

c = W.Check("dark-mode/edge")
sheet = W.Sheet("theme.css")
doc = W.parse_html("account.html")

TOKENS = ("--bg", "--surface", "--fg", "--muted", "--accent", "--border")

# --- literals live in the token blocks only ------------------------------
stray = [
    (sel, prop, val) for sel, prop, val in sheet.values()
    if not prop.startswith("--") and W.HEX.findall(val)
]
c.eq(stray, [], "no hex colour literal outside the token definitions")

# --- and only the three declared blocks define tokens --------------------
definers = []
for ctx, sel, body in sheet.rules:
    decls = W.declarations(body)
    if any(name in decls for name in TOKENS):
        definers.append((tuple(ctx), sel))
c.eq(len(definers), 3, "exactly three blocks define the palette -- got %r" % (definers,))
for ctx, sel in definers:
    c.ok(":root" in W.squash(sel), "token block %r is scoped to :root" % (sel,))

# --- components read tokens ----------------------------------------------
for cls, prop, token in (
    ("card", "background", "--surface"),
    ("card", "color", "--fg"),
    ("muted", "color", "--muted"),
    ("btn", "color", "--accent"),
):
    got = sheet.base(cls).get(prop)
    c.ok(
        got is not None and "var(%s)" % token in W.squash(got),
        ".%s %s reads var(%s) -- got %r" % (cls, prop, token, got),
    )

body = sheet.merged("body")
c.ok("var(--bg)" in W.squash(body.get("background") or ""), "body background reads var(--bg)")
c.ok("var(--fg)" in W.squash(body.get("color") or ""), "body colour reads var(--fg)")

for cls in ("card", "btn"):
    border = sheet.base(cls).get("border")
    c.ok(
        border is not None and "var(--border)" in W.squash(border),
        ".%s border reads var(--border) -- got %r" % (cls, border),
    )

# --- the light values are still the ones on bare :root -------------------
root = sheet.decls_for(":root")
c.ok(W.same(root.get("--bg"), "#ffffff"), "bare :root is the light theme")

# --- the markup is untouched ---------------------------------------------
c.eq(len(doc.find_all("section", cls="card")), 3, "three cards")
c.eq(len(doc.find_all(cls="btn")), 3, "three buttons")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")
c.eq(len(doc.find_all("style")), 0, "no <style> block")
c.eq(len(doc.find_all("script")), 0, "no <script> element")
html = doc.find("html")
c.ok(html is not None and html.attr("lang") == "en", "<html lang=en> kept")

c.done()
