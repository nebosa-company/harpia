import _webcheck as W

c = W.Check("specificity-bug/core")
sheet = W.Sheet("styles.css")
c.ok(sheet.exists(), "styles.css is present and not empty")

# --- the banner text is legible again ------------------------------------
promo_colour = [
    (sel, decls["color"])
    for _, sel, decls in sheet.rules_for_class("promo__text")
    if "color" in decls
]
c.eq(len(promo_colour), 1, "exactly one rule declares a colour for .promo__text -- got %r" % (promo_colour,))
for sel, value in promo_colour:
    c.ok(
        W.same(value, "var(--promo-fg)"),
        ".promo__text colour comes from --promo-fg (rule %r declares %r)" % (sel, value),
    )

# --- the small print keeps the tinted-section treatment -------------------
note = [
    (sel, decls["color"])
    for _, sel, decls in sheet.rules_for_class("note")
    if "color" in decls
]
c.ok(
    any(W.same(v, "var(--promo-bg)") for _, v in note),
    ".note is still recoloured with --promo-bg inside a tinted section",
)

# --- the current page's link wins ----------------------------------------
base = W.specificity(".nav .nav__link")
active = [
    (sel, decls["text-decoration-color"])
    for _, sel, decls in sheet.rules_for_class("nav__link--active")
    if "text-decoration-color" in decls
]
c.ok(active, "a rule sets text-decoration-color on .nav__link--active")
winners = [
    (sel, val) for sel, val in active
    if W.specificity(sel) >= base and W.same(val, "var(--accent)")
]
c.ok(
    winners,
    "the active-link rule is at least as specific as %r and uses var(--accent) -- got %r"
    % (".nav .nav__link", active),
)

# --- the base link rule is untouched -------------------------------------
base_rules = [
    decls for _, sel, decls in sheet.matching(".nav .nav__link")
    if W.norm_sel(sel) == ".nav .nav__link"
]
c.ok(base_rules, "the .nav .nav__link base rule is still there")
if base_rules:
    merged = {}
    for d in base_rules:
        merged.update(d)
    c.eq(
        merged.get("text-decoration-color"), "transparent",
        "inactive links keep a transparent underline",
    )
    c.eq(merged.get("text-decoration"), "underline", "the underline itself is unchanged")

c.done()
