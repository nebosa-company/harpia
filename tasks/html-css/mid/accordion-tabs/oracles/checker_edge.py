import _webcheck as W

c = W.Check("accordion-tabs/edge")
doc = W.parse_html("help.html")
sheet = W.Sheet("widgets.css")

# --- the radios stay in the keyboard order -------------------------------
radio = sheet.base("tabs__radio")
c.ok(
    radio.get("display") != "none",
    ".tabs__radio is not removed with display: none -- got %r" % radio.get("display"),
)
c.ok(
    radio.get("visibility") != "hidden",
    ".tabs__radio is not removed with visibility: hidden",
)
c.eq(radio.get("position"), "absolute", ".tabs__radio is taken out of flow")
c.eq(radio.get("opacity"), "0", ".tabs__radio is transparent rather than removed")
c.eq(radio.get("width"), "1px", ".tabs__radio collapses to a 1px box")
c.eq(radio.get("height"), "1px", ".tabs__radio collapses to a 1px box")

focus = [
    sel for sel, decls in sheet.all_rules("ANY")
    if ".tabs__radio:focus-visible" in W.squash(sel)
    and "~" in sel
    and W.sel_has_class(sel, "tabs__list")
    and decls.get("outline")
    and W.squash(decls.get("outline")) not in ("none", "0")
]
c.ok(focus, "focus on a hidden radio shows an outline on .tabs__list")

# --- accordion detail -----------------------------------------------------
summary = sheet.base("accordion__summary")
c.eq(summary.get("cursor"), "pointer", ".accordion__summary shows a pointer cursor")

open_rules = [
    sel for sel, decls in sheet.all_rules("ANY")
    if "[open]" in W.squash(sel)
    and W.sel_has_class(sel, "accordion__summary")
    and decls.get("font-weight")
]
c.ok(open_rules, "an [open] rule weights the summary of the expanded item")

sfocus = [
    sel for sel, decls in sheet.all_rules("ANY")
    if ".accordion__summary:focus-visible" in W.squash(sel) and decls.get("outline")
]
c.ok(sfocus, ".accordion__summary has a :focus-visible outline")

# --- no script anywhere ---------------------------------------------------
c.eq(len(doc.find_all("script")), 0, "no <script> element")
handlers = [(n.tag, k) for n in doc.walk() for k in n.attrs if k.startswith("on")]
c.eq(handlers, [], "no inline event-handler attributes")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")

# --- ids and label targets line up ---------------------------------------
by_id = {}
for node in doc.walk():
    if node.attr("id"):
        by_id.setdefault(node.attr("id"), []).append(node)
c.eq(sorted(k for k, v in by_id.items() if len(v) > 1), [], "no duplicate ids")
for name in ("tab-1", "tab-2", "tab-3", "panel-1", "panel-2", "panel-3"):
    c.ok(name in by_id, "id %s exists" % name)
targets = [n.attr("for") for n in doc.find_all("label")]
c.eq([t for t in targets if t not in by_id], [], "every label points at a real control")

# --- the copy survived the restructure -----------------------------------
text = " ".join(doc.stext().split())
for fragment in (
    "completes in under ten minutes",
    "invited again on the other side",
    "adding a payment method restores write access",
    "writes only to your home directory",
    "stored in the operating system keychain",
    "addressable by its commit for the next ninety days",
):
    c.ok(fragment in text, "kept the sentence about %r" % fragment[:34])

c.done()
