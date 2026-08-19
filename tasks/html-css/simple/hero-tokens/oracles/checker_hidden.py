import _webcheck as W

c = W.Check("hero-tokens/core")
tokens = W.Sheet("tokens.css")
hero = W.Sheet("hero.css")

c.ok(tokens.exists(), "tokens.css exists and is not empty")
c.ok(hero.exists(), "hero.css exists and is not empty")

root = tokens.decls_for(":root")
EXPECTED = [
    ("--hero-bg", "#0f1729"),
    ("--hero-fg", "#f4f7ff"),
    ("--hero-accent", "#ffb347"),
    ("--hero-accent-ink", "#2a1a00"),
    ("--space-2", "0.5rem"),
    ("--space-4", "1rem"),
    ("--space-6", "1.5rem"),
    ("--space-8", "2rem"),
    ("--radius-lg", "12px"),
    ("--measure", "60ch"),
]
for name, value in EXPECTED:
    c.ok(
        W.same(root.get(name), value),
        "%s is defined on :root as %s -- got %r" % (name, value, root.get(name)),
    )

block = hero.base("hero")
c.ok(W.same(block.get("background"), "var(--hero-bg)"), ".hero background token -- got %r" % block.get("background"))
c.ok(W.same(block.get("color"), "var(--hero-fg)"), ".hero colour token -- got %r" % block.get("color"))
c.ok(
    W.same(block.get("padding"), "var(--space-8) var(--space-6)"),
    ".hero padding tokens -- got %r" % block.get("padding"),
)

title = hero.base("hero__title")
c.ok(W.same(title.get("margin"), "0 0 var(--space-4)"), ".hero__title margin -- got %r" % title.get("margin"))

lede = hero.base("hero__lede")
c.ok(W.same(lede.get("max-width"), "var(--measure)"), ".hero__lede max-width -- got %r" % lede.get("max-width"))
c.ok(W.same(lede.get("margin"), "0 0 var(--space-6)"), ".hero__lede margin -- got %r" % lede.get("margin"))

cta = hero.base("hero__cta")
c.ok(W.same(cta.get("background"), "var(--hero-accent)"), ".hero__cta background -- got %r" % cta.get("background"))
c.ok(W.same(cta.get("color"), "var(--hero-accent-ink)"), ".hero__cta colour -- got %r" % cta.get("color"))
c.ok(W.same(cta.get("border-radius"), "var(--radius-lg)"), ".hero__cta radius -- got %r" % cta.get("border-radius"))
c.ok(
    W.same(cta.get("padding"), "var(--space-2) var(--space-6)"),
    ".hero__cta padding -- got %r" % cta.get("padding"),
)

c.done()
