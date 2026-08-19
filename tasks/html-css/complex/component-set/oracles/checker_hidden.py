import _webcheck as W

c = W.Check("component-set/core")
doc = W.parse_html("components.html")
body = W.body_of(doc)

by_id = {}
for node in doc.walk():
    if node.attr("id"):
        by_id.setdefault(node.attr("id"), []).append(node)
c.eq(sorted(k for k, v in by_id.items() if len(v) > 1), [], "no duplicate ids")

# --- skip link ------------------------------------------------------------
first = body.children[0] if body.children else None
c.ok(first is not None and first.tag == "a" and first.has_class("skip-link"),
     "the skip link is the first element in <body>")
if first is not None and first.tag == "a":
    c.eq(first.attr("href"), "#main", "the skip link targets #main")
    c.eq(first.stext(), "Skip to content", "skip link text")
c.ok("main" in by_id, "an element carries id=main")

# --- breadcrumb -----------------------------------------------------------
crumb = doc.find("nav", cls="breadcrumb")
if c.ok(crumb is not None, "<nav class=breadcrumb>"):
    c.eq(crumb.attr("aria-label"), "Breadcrumb", "breadcrumb aria-label")
    lists = crumb.find_all("ol", cls="breadcrumb__list")
    c.eq(len(lists), 1, "the breadcrumb uses an ordered list")
    if lists:
        items = lists[0].kids("li")
        c.eq(len(items), 3, "three breadcrumb items")
        c.eq(
            [n.has_class("breadcrumb__item") for n in items],
            [True] * 3,
            "each item carries breadcrumb__item",
        )
        links = crumb.find_all("a", cls="breadcrumb__link")
        c.eq(len(links), 3, "three breadcrumb links")
        c.eq(
            [n.stext() for n in links],
            ["Account", "Billing", "Invoices"],
            "breadcrumb trail, in order",
        )
        current = [n for n in links if n.attr("aria-current") == "page"]
        c.eq(len(current), 1, "exactly one link carries aria-current=page")
        if current and links:
            c.ok(current[0] is links[-1], "the last crumb is the current page")

# --- switch ---------------------------------------------------------------
switch = doc.find(cls="switch")
if c.ok(switch is not None, "the .switch component is present"):
    controls = switch.find_all("input", cls="switch__input")
    if c.eq(len(controls), 1, "one .switch__input"):
        control = controls[0]
        c.eq(control.attr("type"), "checkbox", "the switch is a native checkbox")
        c.eq(control.attr("role"), "switch", "the checkbox is exposed as role=switch")
        c.eq(control.attr("id"), "switch-emails", "the switch id")
        c.ok(control.has_attr("checked"), "the switch starts on")
        c.ok(
            not control.has_attr("aria-checked"),
            "the switch does not restate its state with aria-checked",
        )
    labels = [n for n in doc.find_all("label") if n.attr("for") == "switch-emails"]
    if c.eq(len(labels), 1, "one label for the switch"):
        c.ok(labels[0].has_class("switch__label"), "the label carries switch__label")
        c.eq(labels[0].stext(), "Product emails", "switch label text")

# --- disclosure -----------------------------------------------------------
disclosure = doc.find("details", cls="disclosure")
if c.ok(disclosure is not None, "<details class=disclosure>"):
    summaries = disclosure.kids("summary")
    if c.eq(len(summaries), 1, "the disclosure has one <summary>"):
        c.ok(summaries[0].has_class("disclosure__summary"), "summary carries disclosure__summary")
        c.eq(
            summaries[0].stext(),
            "What counts as an active project?",
            "disclosure question text",
        )
    c.ok(not disclosure.has_attr("open"), "the disclosure starts collapsed")
    c.eq(len(disclosure.find_all(cls="disclosure__panel")), 1, "one .disclosure__panel")

# --- progress -------------------------------------------------------------
bars = doc.find_all("progress")
if c.eq(len(bars), 1, "one native <progress> element"):
    bar = bars[0]
    c.ok(bar.has_class("progress"), "the progress bar carries class progress")
    c.eq(bar.attr("id"), "upload", "the progress bar id")
    c.eq(bar.attr("max"), "100", "progress max")
    c.eq(bar.attr("value"), "72", "progress value")
    c.ok(
        bar.attr("role") is None,
        "the native element is not re-declared with a role",
    )
labels = [n for n in doc.find_all("label") if n.attr("for") == "upload"]
c.eq(len(labels), 1, "one label for the progress bar")
c.eq(
    [n.attr("role") for n in doc.walk() if n.attr("role") == "progressbar"],
    [],
    "no hand-rolled role=progressbar",
)

# --- alert ----------------------------------------------------------------
alerts = doc.find_all(cls="alert")
if c.eq(len(alerts), 1, "one .alert"):
    alert = alerts[0]
    c.eq(alert.attr("role"), "alert", "the alert carries role=alert")
    c.ok(alert.has_class("alert--error"), "the alert carries the error modifier")
    c.ok(alert.stext().strip(), "the alert carries its message")

# --- tooltip --------------------------------------------------------------
tooltip = doc.find(cls="tooltip")
if c.ok(tooltip is not None, "the .tooltip component is present"):
    triggers = tooltip.find_all("button", cls="tooltip__trigger")
    if c.eq(len(triggers), 1, "one .tooltip__trigger button"):
        trigger = triggers[0]
        c.eq(trigger.attr("type"), "button", "the trigger declares type=button")
        c.eq(
            trigger.attr("aria-describedby"),
            "tip-retention",
            "the trigger points at the bubble with aria-describedby",
        )
        c.eq(trigger.stext(), "Retention", "trigger text")
    bubbles = tooltip.find_all(cls="tooltip__bubble")
    if c.eq(len(bubbles), 1, "one .tooltip__bubble"):
        c.eq(bubbles[0].attr("id"), "tip-retention", "the bubble id")
        c.eq(bubbles[0].attr("role"), "tooltip", "the bubble carries role=tooltip")
        c.ok(bubbles[0].stext().strip(), "the bubble carries its explanation")

# --- nothing is scripted --------------------------------------------------
c.eq(len(doc.find_all("script")), 0, "no <script> element")
c.eq(
    [(n.tag, k) for n in doc.walk() for k in n.attrs if k.startswith("on")],
    [],
    "no inline event-handler attributes",
)

c.done()
