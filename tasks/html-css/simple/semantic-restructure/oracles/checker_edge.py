import _webcheck as W

c = W.Check("semantic-restructure/edge")
doc = W.parse_html("index.html")

# --- no generic wrappers left --------------------------------------------
c.eq(len(doc.find_all("div")), 0, "no <div> elements remain")
c.eq(len(doc.find_all("span")), 0, "no <span> elements remain")

# --- outline --------------------------------------------------------------
headings = [n.tag for n in doc.walk() if n.tag in ("h1", "h2", "h3", "h4", "h5", "h6")]
c.eq(headings, ["h1", "h2", "h2", "h2", "h2"], "heading outline in document order")

asides = doc.find_all("aside", cls="sidebar")
if c.eq(len(asides), 1, "one sidebar"):
    aside = asides[0]
    c.eq(aside.attr("aria-label"), "About this blog", "sidebar aria-label")
    titles = aside.find_all("h2", cls="sidebar__title")
    c.eq(len(titles), 1, "sidebar has one <h2 class=sidebar__title>")
    if titles:
        c.eq(titles[0].stext(), "About this blog", "sidebar heading text")
    bodies = aside.find_all("p", cls="sidebar__body")
    c.eq(len(bodies), 1, "sidebar body is a <p class=sidebar__body>")
    if bodies:
        c.eq(
            bodies[0].stext(),
            "Notes on stylesheets, markup and the parts of the platform that "
            "predate the framework. Updated whenever something breaks.",
            "sidebar body text preserved",
        )

# --- preserved copy -------------------------------------------------------
excerpts = [p.stext() for p in doc.find_all("p", cls="post__excerpt")]
c.eq(
    excerpts,
    [
        "Every colour and spacing value now lives in one file. Component sheets "
        "that carry their own literals drift within a release or two.",
        "A rule that never wins is worse than no rule at all, because it still "
        "looks like intent. We read the cascade aloud in review now.",
        "Readers still print. A stylesheet that hides the chrome and spells out "
        "link targets costs an afternoon and saves a binder.",
    ],
    "excerpt text preserved, in order",
)

footers = doc.find_all("footer", cls="site-footer")
if c.eq(len(footers), 1, "one footer"):
    c.eq(footers[0].stext(), "Cascade Notes 2024 - built by hand.", "footer text")

# --- document chrome kept -------------------------------------------------
html = doc.find("html")
c.ok(html is not None and html.attr("lang") == "en", "<html lang=en> kept")
title = doc.find("title")
c.ok(title is not None and title.stext() == "Cascade Notes", "<title> kept")
c.eq(
    len(doc.find_all("meta", name="viewport")), 1, "viewport meta kept"
)
links = [n for n in doc.find_all("link") if n.attr("rel") == "stylesheet"]
c.eq([n.attr("href") for n in links], ["styles.css"], "stylesheet link kept")

c.done()
