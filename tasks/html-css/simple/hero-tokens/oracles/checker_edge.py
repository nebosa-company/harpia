import _webcheck as W

c = W.Check("hero-tokens/edge")
tokens = W.Sheet("tokens.css")
hero = W.Sheet("hero.css")
doc = W.parse_html("index.html")

# --- the component sheet carries no literals -----------------------------
c.eq(hero.hex_literals(), [], "hero.css declares no hex colour literals")
raw_lengths = [
    (sel, prop, val) for sel, prop, val in hero.values()
    if prop in ("padding", "margin", "max-width", "border-radius", "gap")
    and "var(" not in val and any(u in val for u in ("px", "rem", "em", "ch", "%"))
]
c.eq(raw_lengths, [], "hero.css spends tokens, not raw lengths")

# --- tokens.css is only tokens -------------------------------------------
selectors = sorted(set(hero_sel for _, hero_sel, _ in tokens.rules))
c.eq(selectors, [":root"], "tokens.css contains only the :root block")
non_custom = sorted(p for p in tokens.decls_for(":root") if not p.startswith("--"))
c.eq(non_custom, [], ":root declares custom properties only")

# --- load order -----------------------------------------------------------
sheets = [
    n.attr("href") for n in doc.find_all("link")
    if (n.attr("rel") or "").lower() == "stylesheet"
]
c.eq(sheets, ["base.css", "tokens.css", "hero.css"], "stylesheets are linked in order")

# --- the template markup is untouched ------------------------------------
sections = doc.find_all("section", cls="hero")
if c.eq(len(sections), 1, "one <section class=hero>"):
    section = sections[0]
    titles = section.find_all("h1", cls="hero__title")
    c.eq(len(titles), 1, "the hero holds one <h1 class=hero__title>")
    if titles:
        c.eq(titles[0].stext(), "Ship the boring parts on Friday", "hero title text")
    ledes = section.find_all("p", cls="hero__lede")
    c.eq(len(ledes), 1, "the hero holds one <p class=hero__lede>")
    ctas = section.find_all("a", cls="hero__cta")
    c.eq(len(ctas), 1, "the call to action is one <a class=hero__cta>")
    if ctas:
        c.eq(ctas[0].attr("href"), "/start", "the call to action still links to /start")
        c.eq(ctas[0].stext(), "Start a free trial", "call-to-action text")

c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")
c.eq(len(doc.find_all("style")), 0, "no <style> block in the document")

# --- the button reads as a button ----------------------------------------
cta = hero.base("hero__cta")
c.eq(cta.get("display"), "inline-block", ".hero__cta is inline-block")
c.eq(cta.get("text-decoration"), "none", ".hero__cta drops the link underline")

c.done()
