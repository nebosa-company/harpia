import _webcheck as W

c = W.Check("stacking-context/core")
doc = W.parse_html("checkout.html")
sheet = W.Sheet("checkout.css")
body = W.body_of(doc)

# --- the modal escaped the shell ------------------------------------------
modals = doc.find_all(cls="modal")
if c.eq(len(modals), 1, "one .modal root"):
    modal = modals[0]
    c.ok(modal.parent is body, "the modal is a direct child of <body>")
    c.ok(
        "page-shell" not in [x for a in modal.ancestors() for x in a.classes()],
        "the modal is no longer nested inside .page-shell",
    )
    c.ok(modal.has_class("is-open"), "the modal keeps its is-open state class")

shells = doc.find_all(cls="page-shell")
c.eq(len(shells), 1, "the .page-shell wrapper is still there")
if shells:
    c.ok(shells[0].parent is body, ".page-shell is still a direct child of <body>")
    c.eq(len(shells[0].find_all("main")), 1, ".page-shell still holds the page content")

# --- the shell no longer forms a stacking context -------------------------
shell = sheet.base("page-shell")
TRAPS = (
    "transform", "filter", "backdrop-filter", "perspective", "will-change",
    "isolation", "contain", "mix-blend-mode", "translate", "rotate", "scale",
)
for prop in TRAPS:
    value = shell.get(prop)
    c.ok(
        value is None or W.squash(value) in ("none", "auto", "normal"),
        ".page-shell must not declare %s (%r creates a stacking context)" % (prop, value),
    )
opacity = shell.get("opacity")
c.ok(
    opacity is None or W.squash(opacity) == "1",
    ".page-shell opacity must stay 1 -- got %r" % opacity,
)

# --- the modal root still owns the top layer ------------------------------
root = sheet.base("modal")
c.eq(root.get("position"), "fixed", ".modal is position: fixed")
c.eq(root.get("inset"), "0", ".modal covers the viewport with inset: 0")
c.eq(root.get("z-index"), "1000", ".modal keeps z-index: 1000")

# --- the dialog is above the overlay --------------------------------------
overlay = sheet.base("modal__overlay")
dialog = sheet.base("modal__dialog")


def z(decls, label):
    raw = decls.get("z-index")
    try:
        return int(raw)
    except (TypeError, ValueError):
        c.ok(False, "%s declares a numeric z-index -- got %r" % (label, raw))
        return None


zo = z(overlay, ".modal__overlay")
zd = z(dialog, ".modal__dialog")
if zo is not None and zd is not None:
    c.ok(zo < zd, "the dialog stacks above the overlay -- overlay %d, dialog %d" % (zo, zd))

c.done()
