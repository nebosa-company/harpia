import _webcheck as W

c = W.Check("data-table/core")
doc = W.parse_html("report.html")

tables = doc.find_all("table", cls="report")
if not c.eq(len(tables), 1, "one <table class=report>"):
    c.done()
table = tables[0]

caps = table.find_all("caption")
c.eq(len(caps), 1, "the table has a <caption>")
if caps:
    c.ok(caps[0].has_class("report__caption"), "caption has class report__caption")
    c.eq(
        caps[0].stext(),
        "Quarterly revenue by region, 2024 (EUR thousands)",
        "caption text",
    )

heads = table.find_all("thead")
bodies = table.find_all("tbody")
foots = table.find_all("tfoot")
c.eq(len(heads), 1, "one <thead>")
c.eq(len(bodies), 1, "one <tbody>")
c.eq(len(foots), 1, "one <tfoot>")

# --- column headers -------------------------------------------------------
if heads:
    rows = heads[0].find_all("tr")
    c.eq(len(rows), 1, "thead holds one row")
    if rows:
        cells = rows[0].find_all(("th", "td"))
        c.eq([n.tag for n in cells], ["th"] * 5, "every header cell is a <th>")
        c.eq(
            [n.attr("scope") for n in cells],
            ["col"] * 5,
            "every column header carries scope=col",
        )
        c.eq(
            [n.stext() for n in cells],
            ["Region", "Q1", "Q2", "Q3", "Q4"],
            "column header text",
        )

# --- data rows ------------------------------------------------------------
DATA = [
    ("North", ["412", "468", "501", "559"]),
    ("South", ["318", "302", "349", "387"]),
    ("East", ["205", "244", "268", "291"]),
    ("West", ["176", "191", "210", "233"]),
]

if bodies:
    rows = bodies[0].find_all("tr")
    c.eq(len(rows), 4, "tbody holds four rows")
    for i, row in enumerate(rows[:4]):
        region, values = DATA[i]
        cells = row.find_all(("th", "td"))
        if not c.eq(len(cells), 5, "row %s has five cells" % region):
            continue
        c.eq(cells[0].tag, "th", "row %s starts with a <th>" % region)
        c.eq(cells[0].attr("scope"), "row", "row %s header carries scope=row" % region)
        c.eq(cells[0].stext(), region, "row %s header text" % region)
        c.eq([n.tag for n in cells[1:]], ["td"] * 4, "row %s data cells are <td>" % region)
        c.eq([n.stext() for n in cells[1:]], values, "row %s values" % region)

# --- totals ---------------------------------------------------------------
if foots:
    rows = foots[0].find_all("tr")
    c.eq(len(rows), 1, "tfoot holds one row")
    if rows:
        cells = rows[0].find_all(("th", "td"))
        if c.eq(len(cells), 5, "the total row has five cells"):
            c.eq(cells[0].tag, "th", "the total row starts with a <th>")
            c.eq(cells[0].attr("scope"), "row", "the total header carries scope=row")
            c.eq(cells[0].stext(), "Total", "the total row is labelled Total")
            c.eq(
                [n.stext() for n in cells[1:]],
                ["1111", "1205", "1328", "1470"],
                "column totals",
            )

c.done()
