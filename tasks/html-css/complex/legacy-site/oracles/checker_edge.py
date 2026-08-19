import _webcheck as W

c = W.Check("legacy-site/edge")
sheet = W.Sheet("css/site.css")

PAGES = ["index.html", "about.html", "pricing.html", "contact.html"]
NAV = [
    ("index.html", "Home"),
    ("about.html", "About"),
    ("pricing.html", "Pricing"),
    ("contact.html", "Contact"),
]

docs = {}
for page in PAGES:
    doc = W.parse_html(page)
    docs[page] = doc
    c.ok(doc.find("html") is not None, "%s exists and parses" % page)

# --- the shared skeleton, on every page ----------------------------------
for page in PAGES:
    doc = docs[page]
    html = doc.find("html")
    c.ok(html is not None and html.attr("lang") == "en", "%s: <html lang=en>" % page)
    title = doc.find("title")
    c.ok(title is not None and title.stext().strip(), "%s: has a title" % page)
    c.eq(
        [n.attr("href") for n in doc.find_all("link") if (n.attr("rel") or "").lower() == "stylesheet"],
        ["css/site.css"],
        "%s: links the shared stylesheet" % page,
    )
    c.eq(len(doc.find_all("meta", name="viewport")), 1, "%s: viewport meta" % page)

    header = doc.find("header", cls="site-header")
    c.ok(header is not None, "%s: has the site header" % page)
    if header is not None:
        inner = header.find(cls="site-header__inner")
        c.ok(inner is not None and inner.has_class("container"), "%s: header inner is a container" % page)
        brand = header.find("a", cls="site-header__brand")
        c.ok(brand is not None and brand.attr("href") == "index.html", "%s: brand link" % page)

    main = doc.find("main")
    c.ok(main is not None, "%s: has a <main>" % page)
    if main is not None:
        c.ok(main.has_class("container"), "%s: main is a container" % page)
        c.ok(main.has_class("site-grid"), "%s: main is the site grid" % page)
        for region in ("site-grid__main", "site-grid__aside", "site-grid__notes"):
            c.eq(len(main.find_all(cls=region)), 1, "%s: one .%s" % (page, region))

    footer = doc.find("footer", cls="site-footer")
    c.ok(footer is not None, "%s: has the site footer" % page)
    if footer is not None:
        c.ok(
            "Northbeam BV, Rotterdam. Surveys since 2011." in footer.stext(),
            "%s: footer line matches the other pages" % page,
        )

    c.eq(len(doc.find_all("h1")), 1, "%s: exactly one <h1>" % page)
    c.eq(len(W.inline_styled(doc)), 0, "%s: no inline style attributes" % page)
    c.eq(len(doc.find_all("style")), 0, "%s: no <style> block" % page)

# --- the navigation, extended and self-consistent -------------------------
for page in PAGES:
    doc = docs[page]
    nav = doc.find("nav", cls="site-nav")
    if not c.ok(nav is not None, "%s: has the primary nav" % page):
        continue
    c.eq(nav.attr("aria-label"), "Primary", "%s: nav aria-label" % page)
    lists = nav.find_all("ul")
    c.eq(len(lists), 1, "%s: one nav list" % page)
    if not lists:
        continue
    items = lists[0].kids("li")
    c.eq(len(items), 4, "%s: four nav items" % page)
    links = [n for item in items for n in item.find_all("a")]
    c.eq(
        [(n.attr("href"), n.stext()) for n in links],
        NAV,
        "%s: nav links and order" % page,
    )
    current = [n for n in links if n.attr("aria-current") == "page"]
    c.eq(len(current), 1, "%s: exactly one aria-current=page" % page)
    if current:
        c.eq(current[0].attr("href"), page, "%s: aria-current marks this page" % page)

# --- the new page follows the pattern ------------------------------------
pricing = docs["pricing.html"]
c.ok(
    (pricing.find("title").stext() if pricing.find("title") else "").startswith("Pricing"),
    "pricing.html: the title names the page",
)
head = pricing.find("h1")
c.ok(head is not None and head.stext() == "Pricing", "pricing.html: <h1>Pricing</h1>")

tables = pricing.find_all("div", cls="pricing-table")
if c.eq(len(tables), 1, "pricing.html: one .pricing-table"):
    plans = tables[0].kids("article", cls="plan")
    c.eq(len(plans), 3, "pricing.html: three .plan cards")
    for i, plan in enumerate(plans):
        label = "plan %d" % (i + 1)
        names = plan.find_all("h2", cls="plan__name")
        c.eq(len(names), 1, "pricing.html: %s has one h2.plan__name" % label)
        prices = plan.find_all("p", cls="plan__price")
        c.eq(len(prices), 1, "pricing.html: %s has one p.plan__price" % label)
        lists = plan.find_all("ul", cls="plan__features")
        c.eq(len(lists), 1, "pricing.html: %s has one ul.plan__features" % label)
        if lists:
            c.ok(len(lists[0].kids("li")) >= 2, "pricing.html: %s lists at least two features" % label)
    main = pricing.find(cls="site-grid__main")
    c.ok(
        main is not None and tables[0] in list(main.walk()),
        "pricing.html: the pricing table sits inside .site-grid__main",
    )

# --- and the stylesheet grew to match ------------------------------------
table = sheet.base("pricing-table")
c.eq(table.get("display"), "grid", ".pricing-table is a grid")
c.eq(table.get("grid-template-columns"), "1fr", ".pricing-table is single column by default")
c.ok(table.get("gap"), ".pricing-table declares a gap")
wide = sheet.base("pricing-table", cond="(min-width: 48rem)")
c.ok(
    W.same(wide.get("grid-template-columns"), "repeat(3, 1fr)"),
    ".pricing-table becomes three tracks at 48rem -- got %r" % wide.get("grid-template-columns"),
)
c.ok(sheet.base("plan").get("border"), ".plan declares a border like the other cards")

c.done()
