import _webcheck as W

c = W.Check("data-table/edge")
doc = W.parse_html("report.html")
sheet = W.Sheet("styles.css")

table = doc.find("table", cls="report")
if not c.ok(table is not None, "the report table is present"):
    c.done()

# --- the totals really are the sums of the column above them -------------
body = table.find("tbody")
foot = table.find("tfoot")
if body is not None and foot is not None:
    columns = [[], [], [], []]
    for row in body.find_all("tr"):
        cells = row.find_all("td")
        if len(cells) == 4:
            for i, cell in enumerate(cells):
                try:
                    columns[i].append(int(cell.stext().replace(",", "")))
                except ValueError:
                    columns[i].append(None)
    foot_row = foot.find("tr")
    stated = []
    if foot_row is not None:
        for cell in foot_row.find_all("td"):
            try:
                stated.append(int(cell.stext().replace(",", "")))
            except ValueError:
                stated.append(None)
    computed = [None if None in col or not col else sum(col) for col in columns]
    c.eq(stated, computed, "each stated total equals the sum of its column")

# --- numeric cells are tagged --------------------------------------------
numeric = []
for row in table.find_all("tr"):
    for cell in row.find_all("td"):
        numeric.append(cell)
c.eq(len(numeric), 20, "twenty numeric data cells (16 body + 4 totals)")
untagged = [n.stext() for n in numeric if not n.has_class("num")]
c.eq(untagged, [], "every numeric <td> carries class num")

# --- no presentational markup --------------------------------------------
c.eq(len(doc.find_all(("b", "i", "font", "center"))), 0, "no presentational tags")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")
c.eq(len(table.find_all("br")), 0, "no <br> inside the table")

# --- stylesheet ----------------------------------------------------------
num = sheet.merged("td.num")
c.eq(num.get("text-align"), "right", "numeric cells are right aligned")
c.eq(num.get("font-variant-numeric"), "tabular-nums", "numeric cells use tabular figures")

cap = sheet.merged("caption")
c.eq(cap.get("caption-side"), "top", "the caption sits above the table")
c.eq(cap.get("text-align"), "left", "the caption is left aligned")

tfoot = sheet.merged("tfoot")
c.eq(tfoot.get("font-weight"), "700", "the total row is bold from CSS, not markup")

c.done()
