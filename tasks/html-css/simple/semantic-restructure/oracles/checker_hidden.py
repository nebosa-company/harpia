import _webcheck as W

c = W.Check("semantic-restructure/core")
doc = W.parse_html("index.html")
body = W.body_of(doc)

# --- header ---------------------------------------------------------------
headers = doc.find_all("header", cls="site-header")
c.eq(len(headers), 1, "one <header class=site-header>")
if headers:
    head = headers[0]
    c.ok(head.parent is body, "site-header is a direct child of <body>")
    h1s = head.find_all("h1", cls="site-title")
    c.eq(len(h1s), 1, "header holds one <h1 class=site-title>")
    if h1s:
        c.eq(h1s[0].stext(), "Cascade Notes", "site title text")

    navs = head.find_all("nav", cls="site-nav")
    c.eq(len(navs), 1, "header holds one <nav class=site-nav>")
    if navs:
        nav = navs[0]
        c.eq(nav.attr("aria-label"), "Primary", "nav aria-label")
        uls = nav.find_all("ul")
        c.eq(len(uls), 1, "nav holds exactly one <ul>")
        if uls:
            items = uls[0].kids("li")
            c.eq(len(items), 4, "nav list has four <li>")
            links = []
            for item in items:
                anchors = item.find_all("a")
                c.eq(len(anchors), 1, "each <li> holds exactly one <a>")
                if anchors:
                    links.append((anchors[0].attr("href"), anchors[0].stext()))
            c.eq(
                links,
                [
                    ("index.html", "Home"),
                    ("archive.html", "Archive"),
                    ("about.html", "About"),
                    ("feed.xml", "Feed"),
                ],
                "nav links, in order",
            )

# --- main + posts ---------------------------------------------------------
mains = doc.find_all("main", cls="content")
c.eq(len(mains), 1, "one <main class=content>")
if mains:
    main = mains[0]
    c.ok(main.parent is body, "main is a direct child of <body>")
    posts = main.find_all("article", cls="post")
    c.eq(len(posts), 3, "main holds three <article class=post>")

    expected = [
        ("Why we froze the design tokens", "2024-03-05", "5 March 2024"),
        ("Reading the cascade out loud", "2024-04-18", "18 April 2024"),
        ("Print is not a second-class medium", "2024-05-02", "2 May 2024"),
    ]
    for i, post in enumerate(posts[:3]):
        title, iso, shown = expected[i]
        titles = post.find_all("h2", cls="post__title")
        c.eq(len(titles), 1, "post %d has one <h2 class=post__title>" % (i + 1))
        if titles:
            c.eq(titles[0].stext(), title, "post %d title text" % (i + 1))
        times = post.find_all("time", cls="post__date")
        c.eq(len(times), 1, "post %d has one <time class=post__date>" % (i + 1))
        if times:
            c.eq(times[0].attr("datetime"), iso, "post %d datetime" % (i + 1))
            c.eq(times[0].stext(), shown, "post %d visible date" % (i + 1))
        paras = post.find_all("p", cls="post__excerpt")
        c.eq(len(paras), 1, "post %d has one <p class=post__excerpt>" % (i + 1))

# --- aside + footer -------------------------------------------------------
asides = doc.find_all("aside", cls="sidebar")
c.eq(len(asides), 1, "one <aside class=sidebar>")
if asides:
    c.ok(asides[0].parent is body, "sidebar is a direct child of <body>")
    c.ok("main" not in asides[0].ancestor_tags(), "sidebar sits outside <main>")

footers = doc.find_all("footer", cls="site-footer")
c.eq(len(footers), 1, "one <footer class=site-footer>")
if footers:
    c.ok(footers[0].parent is body, "footer is a direct child of <body>")

c.done()
