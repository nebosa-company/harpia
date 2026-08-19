import _webcheck as W

c = W.Check("landing-page/core")
doc = W.parse_html("index.html")
body = W.body_of(doc)

by_id = {}
for node in doc.walk():
    if node.attr("id"):
        by_id.setdefault(node.attr("id"), []).append(node)
c.eq(sorted(k for k, v in by_id.items() if len(v) > 1), [], "no duplicate ids")

# --- document chrome ------------------------------------------------------
html = doc.find("html")
c.ok(html is not None and html.attr("lang") == "en", "<html lang=en>")
title = doc.find("title")
c.ok(
    title is not None and title.stext() == "Halyard - release automation",
    "page title -- got %r" % (title.stext() if title else None),
)
desc = [n for n in doc.find_all("meta") if (n.attr("name") or "").lower() == "description"]
c.eq(len(desc), 1, "one meta description")
if desc:
    c.ok((desc[0].attr("content") or "").strip(), "the meta description has content")

sheets = [n.attr("href") for n in doc.find_all("link") if (n.attr("rel") or "").lower() == "stylesheet"]
c.eq(
    sheets,
    ["css/tokens.css", "css/layout.css", "css/components.css"],
    "the three stylesheets, in order",
)
c.eq(len(doc.find_all("style")), 0, "no <style> block")
c.eq(len(doc.find_all("script")), 0, "no <script> element")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")

# --- landmarks ------------------------------------------------------------
top = [n for n in body.children]
c.eq(
    [n.tag for n in top],
    ["a", "header", "main", "footer"],
    "body holds the skip link, header, main and footer",
)
if top and top[0].tag == "a":
    c.ok(top[0].has_class("skip-link"), "the first element is the skip link")
    c.eq(top[0].attr("href"), "#main", "the skip link targets #main")
    c.eq(top[0].stext(), "Skip to content", "skip link text")

header = doc.find("header", cls="site-header")
if c.ok(header is not None, "<header class=site-header>"):
    inner = header.find(cls="site-header__inner")
    c.ok(inner is not None, ".site-header__inner is present")
    c.ok(inner is not None and inner.has_class("container"), "the header inner is a .container")
    brand = header.find("a", cls="site-header__brand")
    c.ok(brand is not None and brand.attr("href") == "/", "the brand links to /")
    nav = header.find("nav", cls="site-nav")
    if c.ok(nav is not None, "<nav class=site-nav>"):
        c.eq(nav.attr("aria-label"), "Primary", "primary nav aria-label")
        lists = nav.find_all("ul")
        c.eq(len(lists), 1, "the primary nav holds one <ul>")
        if lists:
            items = lists[0].kids("li")
            c.eq(len(items), 4, "four navigation items")
            got = []
            for item in items:
                links = item.find_all("a")
                c.eq(len(links), 1, "each <li> holds exactly one <a>")
                if links:
                    got.append((links[0].attr("href"), links[0].stext()))
            c.eq(
                got,
                [
                    ("#features", "Features"),
                    ("#pricing", "Pricing"),
                    ("#faq", "FAQ"),
                    ("#contact", "Contact"),
                ],
                "navigation links, in order",
            )

main = doc.find("main")
if not c.ok(main is not None and main.attr("id") == "main", "<main id=main>"):
    c.done()

# --- the five sections ----------------------------------------------------
sections = [n for n in main.find_all("section") if n.attr("id")]
c.eq(
    [n.attr("id") for n in sections],
    ["hero", "features", "pricing", "faq", "contact"],
    "five sections, in order",
)
for section in sections:
    sid = section.attr("id")
    c.eq(section.attr("aria-labelledby"), "%s-title" % sid, "#%s aria-labelledby" % sid)
    heads = by_id.get("%s-title" % sid, [])
    if c.eq(len(heads), 1, "one element with id=%s-title" % sid):
        c.eq(heads[0].tag, "h1" if sid == "hero" else "h2", "#%s heading level" % sid)
c.eq(len(doc.find_all("h1")), 1, "exactly one <h1>")

# --- hero -----------------------------------------------------------------
hero = by_id.get("hero", [None])[0]
if hero is not None:
    c.eq(len(hero.find_all("p", cls="hero__lede")), 1, "the hero has one .hero__lede")
    ctas = [n for n in hero.find_all("a", cls="btn") if n.has_class("btn--primary")]
    c.eq(len(ctas), 1, "the hero has one primary button")
    if ctas:
        c.eq(ctas[0].attr("href"), "#contact", "the hero button links to #contact")

# --- features -------------------------------------------------------------
features = by_id.get("features", [None])[0]
if features is not None:
    grids = features.find_all("ul", cls="feature-grid")
    c.eq(len(grids), 1, "one <ul class=feature-grid>")
    if grids:
        cards = grids[0].kids("li")
        c.eq(len(cards), 3, "three <li class=feature>")
        for i, card in enumerate(cards):
            c.ok(card.has_class("feature"), "feature %d has the block class" % (i + 1))
            c.eq(len(card.find_all("h3", cls="feature__title")), 1, "feature %d title" % (i + 1))
            c.eq(len(card.find_all("p", cls="feature__text")), 1, "feature %d text" % (i + 1))

# --- pricing --------------------------------------------------------------
pricing = by_id.get("pricing", [None])[0]
if pricing is not None:
    grids = pricing.find_all("div", cls="plan-grid")
    c.eq(len(grids), 1, "one <div class=plan-grid>")
    if grids:
        plans = grids[0].kids("article", cls="plan")
        c.eq(len(plans), 3, "three <article class=plan>")
        c.eq(
            len([n for n in plans if n.has_class("plan--featured")]),
            1,
            "exactly one plan is featured",
        )
        for i, plan in enumerate(plans):
            label = "plan %d" % (i + 1)
            c.eq(len(plan.find_all("h3", cls="plan__name")), 1, "%s name" % label)
            c.eq(len(plan.find_all("p", cls="plan__price")), 1, "%s price" % label)
            lists = plan.find_all("ul", cls="plan__features")
            c.eq(len(lists), 1, "%s feature list" % label)
            if lists:
                c.ok(len(lists[0].kids("li")) >= 2, "%s lists at least two features" % label)
            c.ok(
                [n for n in plan.find_all("a", cls="btn") if n.has_class("btn--primary")],
                "%s has a primary button" % label,
            )

# --- faq ------------------------------------------------------------------
faq = by_id.get("faq", [None])[0]
if faq is not None:
    items = faq.find_all("details", cls="faq__item")
    c.eq(len(items), 4, "four <details class=faq__item>")
    for i, item in enumerate(items):
        summaries = item.kids("summary")
        c.eq(len(summaries), 1, "faq %d has one <summary>" % (i + 1))
        if summaries:
            c.ok(summaries[0].has_class("faq__q"), "faq %d summary class" % (i + 1))
    c.eq([n for n in items if n.has_attr("open")], [], "no faq item starts open")

# --- contact --------------------------------------------------------------
contact = by_id.get("contact", [None])[0]
if contact is not None:
    forms = contact.find_all("form", cls="contact-form")
    if c.eq(len(forms), 1, "one <form class=contact-form>"):
        form = forms[0]
        c.eq(form.attr("action"), "/trial", "form action")
        c.eq((form.attr("method") or "").lower(), "post", "form method")
        email = by_id.get("contact-email", [])
        if c.eq(len(email), 1, "one control with id=contact-email"):
            field = email[0]
            c.eq(field.attr("type"), "email", "the email field type")
            c.eq(field.attr("name"), "email", "the email field name")
            c.ok(field.has_attr("required"), "the email field is required")
            c.eq(field.attr("autocomplete"), "email", "the email field autocomplete")
            c.eq(field.attr("aria-describedby"), "contact-hint", "the email field hint link")
        labels = [n for n in form.find_all("label") if n.attr("for") == "contact-email"]
        c.eq(len(labels), 1, "one label for the email field")
        if labels:
            c.eq(labels[0].stext(), "Work email", "label text")
        hints = by_id.get("contact-hint", [])
        if c.eq(len(hints), 1, "one element with id=contact-hint"):
            c.ok(hints[0].has_class("field__hint"), "the hint carries class field__hint")
        buttons = form.find_all("button")
        c.eq(len(buttons), 1, "one submit button")
        if buttons:
            c.eq(buttons[0].attr("type"), "submit", "button type")

# --- footer ---------------------------------------------------------------
footer = doc.find("footer", cls="site-footer")
if c.ok(footer is not None, "<footer class=site-footer>"):
    nav = footer.find("nav")
    c.ok(nav is not None and nav.attr("aria-label") == "Footer", "the footer nav is labelled")
    if nav is not None:
        c.ok(len(nav.find_all("a")) >= 3, "the footer nav lists at least three links")
    c.eq(len(footer.find_all("p", cls="site-footer__legal")), 1, "one legal line")

c.done()
