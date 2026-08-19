import _webcheck as W

c = W.Check("form-validation/core")
sheet = W.Sheet("form.css")

# --- tokens ---------------------------------------------------------------
root = sheet.decls_for(":root")
c.ok(W.same(root.get("--danger"), "#b3261e"), "--danger is defined -- got %r" % root.get("--danger"))
c.ok(W.same(root.get("--ok"), "#1f7a45"), "--ok is defined -- got %r" % root.get("--ok"))

# --- the error text is hidden until it is earned -------------------------
err = sheet.base("field__error")
c.eq(err.get("display"), "none", ".field__error is hidden by default")
c.ok(
    W.same(err.get("color"), "var(--danger)"),
    ".field__error is coloured with var(--danger) -- got %r" % err.get("color"),
)

rules = sheet.all_rules("ANY")

reveal = [
    sel for sel, decls in rules
    if ":user-invalid" in W.squash(sel)
    and "~" in sel
    and W.sel_has_class(sel, "field__error")
    and decls.get("display") == "block"
]
c.ok(reveal, ":user-invalid reveals the sibling .field__error with display: block")

# --- the input borders -----------------------------------------------------
def border_rule(pseudo, token):
    hits = [
        (sel, decls) for sel, decls in rules
        if pseudo in W.squash(sel)
        and W.sel_has_class(sel, "field__input")
        and "~" not in sel
        and (decls.get("border-color") or decls.get("border"))
    ]
    if not c.ok(hits, "a %s rule restyles the .field__input border" % pseudo):
        return
    values = [
        (decls.get("border-color") or decls.get("border") or "") for _, decls in hits
    ]
    c.ok(
        any("var(%s)" % token in W.squash(v) for v in values),
        "the %s border uses var(%s) -- got %r" % (pseudo, token, values),
    )


border_rule(":user-invalid", "--danger")
border_rule(":user-valid", "--ok")

# --- focus is still visible ----------------------------------------------
focus = [
    (sel, decls) for sel, decls in rules
    if ":focus-visible" in W.squash(sel)
    and W.sel_has_class(sel, "field__input")
    and decls.get("outline")
]
c.ok(focus, ".field__input has a :focus-visible outline")
c.eq(
    [sel for sel, decls in focus if W.squash(decls.get("outline")) in ("none", "0")],
    [],
    "the focus outline is visible, not none",
)

# --- required fields are marked ------------------------------------------
marker = [
    (sel, decls) for sel, decls in rules
    if W.sel_has_class(sel, "field--required")
    and "::after" in sel
    and decls.get("content")
]
c.ok(marker, "a .field--required ...::after rule adds the required marker")
c.ok(
    any("*" in (decls.get("content") or "") for _, decls in marker),
    "the required marker is an asterisk -- got %r" % ([d.get("content") for _, d in marker],),
)

c.done()
