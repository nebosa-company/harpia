import _webcheck as W

c = W.Check("accordion-tabs/core")
doc = W.parse_html("help.html")
sheet = W.Sheet("widgets.css")

# --- accordion ------------------------------------------------------------
acc = doc.find(cls="accordion")
if c.ok(acc is not None, "the .accordion container is still there"):
    items = acc.find_all("details", cls="accordion__item")
    c.eq(len(items), 3, "three <details class=accordion__item>")
    questions = [
        "How long does a restore take?",
        "Can I move a project between organisations?",
        "What happens when a trial ends?",
    ]
    for i, item in enumerate(items[:3]):
        summaries = item.kids("summary")
        if c.eq(len(summaries), 1, "item %d has one <summary>" % (i + 1)):
            c.ok(
                summaries[0].has_class("accordion__summary"),
                "item %d summary has class accordion__summary" % (i + 1),
            )
            c.eq(summaries[0].stext(), questions[i], "item %d question text" % (i + 1))
        panels = item.find_all(cls="accordion__panel")
        c.eq(len(panels), 1, "item %d has one .accordion__panel" % (i + 1))
        if panels:
            c.ok(panels[0].stext(), "item %d panel keeps its answer text" % (i + 1))
    opened = [n for n in items if n.has_attr("open")]
    c.eq(len(opened), 1, "exactly one <details> starts open")
    if opened and items:
        c.ok(opened[0] is items[0], "the first item is the one that starts open")

# --- tabs -----------------------------------------------------------------
tabs = doc.find(cls="tabs")
if c.ok(tabs is not None, "the .tabs container is still there"):
    radios = tabs.kids("input")
    c.eq(len(radios), 3, "three radios, direct children of .tabs")
    c.eq(
        [n.attr("id") for n in radios],
        ["tab-1", "tab-2", "tab-3"],
        "radio ids, in order",
    )
    c.eq([n.attr("type") for n in radios], ["radio"] * 3, "all three are radios")
    c.eq([n.attr("name") for n in radios], ["tabs"] * 3, "all three share name=tabs")
    c.eq(
        [n.has_class("tabs__radio") for n in radios],
        [True] * 3,
        "all three carry class tabs__radio",
    )
    checked = [n for n in radios if n.has_attr("checked")]
    c.eq([n.attr("id") for n in checked], ["tab-1"], "tab-1 is checked on load")

    lists = tabs.kids("div", cls="tabs__list")
    c.eq(len(lists), 1, "one .tabs__list, a direct child of .tabs")
    if lists:
        labels = lists[0].find_all("label", cls="tabs__label")
        c.eq(
            [(n.attr("for"), n.stext()) for n in labels],
            [("tab-1", "Install"), ("tab-2", "Configure"), ("tab-3", "Deploy")],
            "tab labels and their targets",
        )

    panels_box = tabs.kids("div", cls="tabs__panels")
    c.eq(len(panels_box), 1, "one .tabs__panels, a direct child of .tabs")
    if panels_box:
        panels = panels_box[0].find_all(cls="tabs__panel")
        c.eq(
            [n.attr("id") for n in panels],
            ["panel-1", "panel-2", "panel-3"],
            "panel ids, in order",
        )

# --- the switching is declared in CSS ------------------------------------
c.eq(len(doc.find_all("script")), 0, "no <script> element")
c.eq(sheet.base("tabs__panel").get("display"), "none", ".tabs__panel is hidden by default")

for n in (1, 2, 3):
    hits = [
        sel for sel, decls in sheet.all_rules("ANY")
        if "#tab-%d:checked" % n in W.squash(sel)
        and "~" in sel
        and "#panel-%d" % n in W.squash(sel)
        and decls.get("display") == "block"
    ]
    c.ok(hits, "#tab-%d:checked reveals #panel-%d through a sibling combinator" % (n, n))

c.done()
