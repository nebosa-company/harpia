import _webcheck as W

c = W.Check("landing-page/edge")
tokens = W.Sheet("css/tokens.css")
layout = W.Sheet("css/layout.css")
components = W.Sheet("css/components.css")
doc = W.parse_html("index.html")

# --- tokens ---------------------------------------------------------------
LIGHT = [
    ("--color-bg", "#ffffff"),
    ("--color-surface", "#f5f8fd"),
    ("--color-fg", "#14181f"),
    ("--color-muted", "#58616f"),
    ("--color-accent", "#1a4fd6"),
    ("--color-accent-fg", "#ffffff"),
    ("--color-border", "#d5dce8"),
    ("--space-1", "0.25rem"),
    ("--space-2", "0.5rem"),
    ("--space-3", "1rem"),
    ("--space-4", "1.5rem"),
    ("--space-5", "2rem"),
    ("--space-6", "3rem"),
    ("--radius", "10px"),
    ("--measure", "68ch"),
    ("--container", "72rem"),
]
root = tokens.decls_for(":root")
for name, value in LIGHT:
    c.ok(W.same(root.get(name), value), "%s is %s -- got %r" % (name, value, root.get(name)))

c.eq(
    sorted(set(sel for _, sel, _ in tokens.rules)),
    [":root"],
    "css/tokens.css holds nothing but :root blocks",
)

DARK = [
    ("--color-bg", "#0d1117"),
    ("--color-surface", "#161b22"),
    ("--color-fg", "#e8edf5"),
    ("--color-muted", "#9aa5b4"),
    ("--color-border", "#2a323d"),
]
cond = "(prefers-color-scheme: dark)"
c.ok(tokens.has_condition(cond), "a @media %s block exists" % cond)
dark = tokens.decls_for(":root", cond=cond)
for name, value in DARK:
    c.ok(W.same(dark.get(name), value), "dark %s is %s -- got %r" % (name, value, dark.get(name)))
c.ok(
    dark.get("--color-accent") is None,
    "the accent is not restated in the dark block",
)

# --- layout ---------------------------------------------------------------
reset = [
    sel for sel, decls in layout.all_rules("ANY")
    if sel.strip() == "*" and decls.get("box-sizing") == "border-box"
]
c.ok(reset, "the universal border-box reset is declared")

container = layout.base("container")
c.eq(container.get("width"), "100%", ".container width")
c.ok(W.same(container.get("max-width"), "var(--container)"), ".container max-width -- got %r" % container.get("max-width"))
c.eq(container.get("margin-inline"), "auto", ".container is centred with margin-inline: auto")
c.ok(W.same(container.get("padding-inline"), "var(--space-3)"), ".container padding-inline -- got %r" % container.get("padding-inline"))

bar = layout.base("site-header__inner")
c.eq(bar.get("display"), "flex", ".site-header__inner is a flex row")
c.eq(bar.get("align-items"), "center", ".site-header__inner aligns items centrally")
c.eq(bar.get("justify-content"), "space-between", ".site-header__inner spreads its children")
c.ok(W.same(bar.get("gap"), "var(--space-4)"), ".site-header__inner gap -- got %r" % bar.get("gap"))

features = layout.base("feature-grid")
c.eq(features.get("display"), "grid", ".feature-grid is a grid")
c.ok(
    W.same(features.get("grid-template-columns"), "repeat(auto-fit, minmax(16rem, 1fr))"),
    ".feature-grid tracks -- got %r" % features.get("grid-template-columns"),
)
c.eq(features.get("list-style"), "none", ".feature-grid drops its markers")
c.eq(features.get("margin"), "0", ".feature-grid margin reset")
c.eq(features.get("padding"), "0", ".feature-grid padding reset")

plans = layout.base("plan-grid")
c.eq(plans.get("display"), "grid", ".plan-grid is a grid")
c.eq(plans.get("grid-template-columns"), "1fr", ".plan-grid is single column by default")
wide = layout.base("plan-grid", cond="(min-width: 48rem)")
c.ok(
    W.same(wide.get("grid-template-columns"), "repeat(3, 1fr)"),
    ".plan-grid becomes three tracks at 48rem -- got %r" % wide.get("grid-template-columns"),
)
c.ok(W.same(layout.base("hero__lede").get("max-width"), "var(--measure)"), ".hero__lede is measured")

# --- components -----------------------------------------------------------
skip = components.base("skip-link")
c.eq(skip.get("position"), "absolute", ".skip-link is taken out of flow")
offscreen = W.numbers(skip.get("left"))
c.ok(
    offscreen and offscreen[0] <= -1000,
    ".skip-link starts off screen -- got left: %r" % skip.get("left"),
)
restored = [
    (sel, decls.get("left")) for sel, decls in components.all_rules("ANY")
    if W.sel_has_class(sel, "skip-link")
    and (":focus" in sel)
    and decls.get("left")
]
c.ok(restored, "a :focus rule brings the skip link back on screen")
c.eq(
    [(s, v) for s, v in restored if v.strip().startswith("-")],
    [],
    "the focused skip link has a non-negative left",
)

btn = components.base("btn")
c.eq(btn.get("display"), "inline-block", ".btn is inline-block")
c.ok(W.same(btn.get("padding"), "var(--space-2) var(--space-4)"), ".btn padding -- got %r" % btn.get("padding"))
c.ok(W.same(btn.get("border-radius"), "var(--radius)"), ".btn radius -- got %r" % btn.get("border-radius"))
c.eq(btn.get("text-decoration"), "none", ".btn drops the link underline")

primary = components.base("btn--primary")
c.ok(W.same(primary.get("background"), "var(--color-accent)"), ".btn--primary background -- got %r" % primary.get("background"))
c.ok(W.same(primary.get("color"), "var(--color-accent-fg)"), ".btn--primary colour -- got %r" % primary.get("color"))

featured = components.base("plan--featured")
c.ok(
    W.same(featured.get("border-color"), "var(--color-accent)"),
    ".plan--featured border-color -- got %r" % featured.get("border-color"),
)

focus = [
    (sel, decls) for sel, decls in components.all_rules("ANY")
    if ":focus-visible" in sel and decls.get("outline")
]
c.ok(focus, "a :focus-visible rule declares an outline")
c.eq(
    [sel for sel, decls in focus if W.squash(decls.get("outline")) in ("none", "0")],
    [],
    "the focus outline is visible",
)

calm = "(prefers-reduced-motion: reduce)"
c.ok(components.has_condition(calm), "a @media %s block exists" % calm)
calm_rules = [
    decls for sel, decls in components.all_rules(calm) if sel.strip() == "*"
]
c.ok(calm_rules, "the reduced-motion block covers every element")
merged = {}
for decls in calm_rules:
    merged.update(decls)
c.eq(merged.get("animation-duration"), "0.01ms", "animations are cut under reduced motion")
c.eq(merged.get("transition-duration"), "0.01ms", "transitions are cut under reduced motion")

# --- colours come from tokens --------------------------------------------
c.eq(layout.hex_literals(), [], "css/layout.css has no hex colour literals")
c.eq(components.hex_literals(), [], "css/components.css has no hex colour literals")

# --- no placeholder-as-label ---------------------------------------------
c.eq(
    [n.attr("id") for n in doc.find_all("input") if n.has_attr("placeholder")],
    [],
    "no control uses a placeholder",
)

c.done()
