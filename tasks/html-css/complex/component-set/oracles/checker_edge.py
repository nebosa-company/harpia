import _webcheck as W

c = W.Check("component-set/edge")
doc = W.parse_html("components.html")
sheet = W.Sheet("components.css")

# --- utilities ------------------------------------------------------------
vh = sheet.base("visually-hidden")
c.eq(vh.get("position"), "absolute", ".visually-hidden is out of flow")
c.eq(vh.get("width"), "1px", ".visually-hidden is 1px wide")
c.eq(vh.get("height"), "1px", ".visually-hidden is 1px tall")
c.eq(vh.get("overflow"), "hidden", ".visually-hidden clips")
c.ok("inset(50%)" in W.squash(vh.get("clip-path") or ""), ".visually-hidden uses clip-path: inset")
c.eq(vh.get("white-space"), "nowrap", ".visually-hidden does not wrap")
c.ok(vh.get("display") != "none", ".visually-hidden is not display: none")

skip = sheet.base("skip-link")
c.eq(skip.get("position"), "absolute", ".skip-link is out of flow")
offscreen = W.numbers(skip.get("left"))
c.ok(offscreen and offscreen[0] <= -1000, ".skip-link starts off screen -- got %r" % skip.get("left"))
restored = [
    (sel, decls.get("left")) for sel, decls in sheet.all_rules("ANY")
    if W.sel_has_class(sel, "skip-link") and ":focus" in sel and decls.get("left")
]
c.ok(restored, "a :focus rule restores the skip link")
c.eq(
    [(s, v) for s, v in restored if v.strip().startswith("-")],
    [],
    "the focused skip link has a non-negative left",
)

focus = [
    (sel, decls) for sel, decls in sheet.all_rules("ANY")
    if ":focus-visible" in sel and decls.get("outline")
]
c.ok(focus, "a :focus-visible rule declares an outline")
c.eq(
    [sel for sel, decls in focus if W.squash(decls.get("outline")) in ("none", "0")],
    [],
    "focus outlines are visible",
)

# --- switch ---------------------------------------------------------------
checked = [
    (sel, decls) for sel, decls in sheet.all_rules("ANY")
    if ":checked" in sel and "+" in sel and W.sel_has_class(sel, "switch__label") and decls
]
if c.ok(checked, "a :checked + .switch__label rule styles the on state"):
    c.ok(
        any(d.get("font-weight") for _, d in checked),
        "the on state changes the label font-weight",
    )
switch_focus = [
    sel for sel, decls in sheet.all_rules("ANY")
    if ":focus-visible" in sel
    and "+" in sel
    and W.sel_has_class(sel, "switch__label")
    and decls.get("outline")
]
c.ok(switch_focus, "focus on the switch input outlines its label")

# --- disclosure -----------------------------------------------------------
c.eq(sheet.base("disclosure__summary").get("cursor"), "pointer", ".disclosure__summary cursor")
open_rules = [
    sel for sel, decls in sheet.all_rules("ANY")
    if "[open]" in W.squash(sel) and W.sel_has_class(sel, "disclosure__summary") and decls
]
c.ok(open_rules, "an [open] rule restyles the expanded summary")

# --- breadcrumb -----------------------------------------------------------
crumbs = sheet.base("breadcrumb__list")
c.eq(crumbs.get("list-style"), "none", ".breadcrumb__list drops its markers")
c.eq(crumbs.get("margin"), "0", ".breadcrumb__list margin reset")
c.eq(crumbs.get("padding"), "0", ".breadcrumb__list padding reset")
current = [
    sel for sel, decls in sheet.all_rules("ANY")
    if 'aria-current="page"' in W.squash(sel).replace("'", '"') and decls
]
c.ok(current, "the current crumb is styled through its aria-current attribute")

# --- tooltip --------------------------------------------------------------
c.eq(sheet.base("tooltip").get("position"), "relative", ".tooltip is the containing block")
bubble = sheet.base("tooltip__bubble")
c.eq(bubble.get("visibility"), "hidden", ".tooltip__bubble is hidden by default")
c.eq(bubble.get("position"), "absolute", ".tooltip__bubble is positioned")
c.ok(
    bubble.get("display") != "none",
    ".tooltip__bubble stays in the accessibility tree (not display: none)",
)
for pseudo in (":hover", ":focus-within"):
    hits = [
        sel for sel, decls in sheet.all_rules("ANY")
        if pseudo in sel
        and W.sel_has_class(sel, "tooltip__bubble")
        and decls.get("visibility") == "visible"
    ]
    c.ok(hits, "a %s rule reveals the tooltip bubble" % pseudo)

# --- alert ----------------------------------------------------------------
c.ok(
    W.same(sheet.base("alert--error").get("border-color"), "var(--danger)"),
    ".alert--error borders in var(--danger) -- got %r" % sheet.base("alert--error").get("border-color"),
)
c.ok(sheet.base("alert").get("border"), ".alert declares a border")

# --- reduced motion -------------------------------------------------------
calm = "(prefers-reduced-motion: reduce)"
c.ok(sheet.has_condition(calm), "a @media %s block exists" % calm)
merged = {}
for sel, decls in sheet.all_rules(calm):
    if sel.strip() == "*":
        merged.update(decls)
c.eq(merged.get("transition-duration"), "0.01ms", "transitions are cut under reduced motion")
c.eq(merged.get("animation-duration"), "0.01ms", "animations are cut under reduced motion")

# --- colours come from tokens --------------------------------------------
stray = [(s, p, v) for s, p, v in sheet.values() if not p.startswith("--") and W.HEX.findall(v)]
c.eq(stray, [], "no hex colour literal outside the token block")

# --- redundant ARIA is not added -----------------------------------------
c.eq(
    [n.tag for n in doc.walk() if n.tag == "button" and n.attr("role") == "button"],
    [],
    "no button restates role=button",
)
c.eq(
    [n.attr("tabindex") for n in doc.walk() if n.attr("tabindex") not in (None, "0", "-1")],
    [],
    "no positive tabindex values",
)
c.eq(len(doc.find_all("style")), 0, "no <style> block in the document")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")

c.done()
