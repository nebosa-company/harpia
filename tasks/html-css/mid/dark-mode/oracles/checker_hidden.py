import _webcheck as W

c = W.Check("dark-mode/core")
sheet = W.Sheet("theme.css")

LIGHT = {
    "--bg": "#ffffff",
    "--surface": "#f4f7fb",
    "--fg": "#171b22",
    "--muted": "#5b6472",
    "--accent": "#1257c9",
    "--border": "#d7dde6",
}
DARK = {
    "--bg": "#0e1116",
    "--surface": "#171c24",
    "--fg": "#eef2f8",
    "--muted": "#9aa6b6",
    "--accent": "#79b0ff",
    "--border": "#2a323d",
}


def check_block(decls, want, label):
    for name, value in sorted(want.items()):
        c.ok(
            W.same(decls.get(name), value),
            "%s defines %s as %s -- got %r" % (label, name, value, decls.get(name)),
        )


# --- 1. the light palette on bare :root ----------------------------------
root = sheet.decls_for(":root")
check_block(root, LIGHT, "the bare :root block")

# --- 2. the system-preference block, guarded ------------------------------
cond = "(prefers-color-scheme: dark)"
c.ok(sheet.has_condition(cond), "a @media %s block exists" % cond)
guarded = [
    (sel, decls) for sel, decls in sheet.all_rules(cond)
    if ":root" in W.squash(sel)
    and ":not(" in W.squash(sel)
    and 'data-theme="light"' in W.squash(sel).replace("'", '"')
]
if c.ok(
    guarded,
    "the dark media block targets :root:not([data-theme=\"light\"]) -- got %r"
    % ([sel for sel, _ in sheet.all_rules(cond)],),
):
    merged = {}
    for _, decls in guarded:
        merged.update(decls)
    check_block(merged, DARK, "the guarded media block")

# --- 3. the explicit override --------------------------------------------
explicit = [
    (sel, decls) for sel, decls in sheet.all_rules(None)
    if ":root" in W.squash(sel)
    and 'data-theme="dark"' in W.squash(sel).replace("'", '"')
    and ":not(" not in W.squash(sel)
]
if c.ok(explicit, "a :root[data-theme=\"dark\"] block exists at the top level"):
    merged = {}
    for _, decls in explicit:
        merged.update(decls)
    check_block(merged, DARK, "the [data-theme=dark] block")

# --- the UA is told which schemes the page supports ----------------------
c.ok(
    W.same(sheet.merged("html").get("color-scheme"), "light dark")
    or W.same(sheet.decls_for(":root").get("color-scheme"), "light dark"),
    "color-scheme: light dark is declared on the root element",
)

c.done()
