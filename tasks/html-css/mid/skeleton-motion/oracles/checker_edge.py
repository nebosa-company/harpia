import _webcheck as W

c = W.Check("skeleton-motion/edge")
doc = W.parse_html("feed.html")
sheet = W.Sheet("feed.css")

# --- reduced motion means no motion, not slower motion -------------------
cond = "(prefers-reduced-motion: reduce)"
c.ok(sheet.has_condition(cond), "a @media %s block exists" % cond)
calm = sheet.base("skeleton", cond=cond)
c.eq(calm.get("animation"), "none", ".skeleton animation is switched off, not slowed")
c.ok(calm.get("background-position") is not None, "the sheen is parked at a fixed position")

# --- the notice is hidden visually, not from assistive tech --------------
vh = sheet.base("visually-hidden")
c.ok(vh.get("display") != "none", ".visually-hidden does not use display: none")
c.ok(vh.get("visibility") != "hidden", ".visually-hidden does not use visibility: hidden")
c.eq(vh.get("position"), "absolute", ".visually-hidden is taken out of flow")
c.eq(vh.get("width"), "1px", ".visually-hidden collapses to 1px wide")
c.eq(vh.get("height"), "1px", ".visually-hidden collapses to 1px tall")
c.eq(vh.get("overflow"), "hidden", ".visually-hidden clips its overflow")
c.ok(
    "inset(50%)" in W.squash(vh.get("clip-path") or ""),
    ".visually-hidden clips with inset(50%%) -- got %r" % vh.get("clip-path"),
)
c.eq(vh.get("white-space"), "nowrap", ".visually-hidden does not wrap")

# --- the variants hold the layout ----------------------------------------
avatar = sheet.base("skeleton--avatar")
c.ok(W.same(avatar.get("width"), "2.5rem"), ".skeleton--avatar width -- got %r" % avatar.get("width"))
c.ok(W.same(avatar.get("height"), "2.5rem"), ".skeleton--avatar height -- got %r" % avatar.get("height"))
c.eq(avatar.get("border-radius"), "50%", ".skeleton--avatar is round")

title = sheet.base("skeleton--title")
c.eq(title.get("width"), "60%", ".skeleton--title width")
c.ok(W.same(title.get("height"), "1.25rem"), ".skeleton--title height -- got %r" % title.get("height"))

text = sheet.base("skeleton--text")
c.eq(text.get("width"), "100%", ".skeleton--text width")
c.ok(W.same(text.get("height"), "0.875rem"), ".skeleton--text height -- got %r" % text.get("height"))

# --- the placeholders carry no content -----------------------------------
bars = doc.find_all("span", cls="skeleton")
c.eq(len(bars), 8, "eight placeholder bars in total")
c.eq([n.stext() for n in bars if n.stext()], [], "placeholder bars are empty")
c.eq([n.attr("aria-hidden") for n in bars], ["true"] * 8, "every bar is aria-hidden")

# --- no leftover placeholder prose ---------------------------------------
page = doc.stext()
c.ok("Loading..." not in page, "the literal 'Loading...' text is gone")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")
c.eq(len(doc.find_all("script")), 0, "no <script> element")

c.done()
