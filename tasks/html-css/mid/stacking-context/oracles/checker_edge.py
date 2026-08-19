import _webcheck as W

c = W.Check("stacking-context/edge")
doc = W.parse_html("checkout.html")
sheet = W.Sheet("checkout.css")

by_id = {}
for node in doc.walk():
    if node.attr("id"):
        by_id.setdefault(node.attr("id"), []).append(node)

# --- the dialog announces itself -----------------------------------------
dialog = doc.find(cls="modal__dialog")
if c.ok(dialog is not None, "the .modal__dialog element is present"):
    c.eq(dialog.attr("role"), "dialog", "the dialog carries role=dialog")
    c.eq(dialog.attr("aria-modal"), "true", "the dialog carries aria-modal=true")
    labelled = dialog.attr("aria-labelledby")
    c.eq(labelled, "modal-title", "the dialog points at its title with aria-labelledby")
    c.eq(len(by_id.get(labelled or "", [])), 1, "exactly one element carries id=modal-title")
    title = doc.find(cls="modal__title")
    c.ok(title is not None and title.attr("id") == "modal-title", "the title carries the id")

overlay = doc.find(cls="modal__overlay")
if c.ok(overlay is not None, "the .modal__overlay element is present"):
    c.eq(overlay.attr("aria-hidden"), "true", "the overlay is hidden from assistive tech")
    c.eq(len(overlay.children), 0, "the overlay holds no content of its own")

# --- both layers are still positioned ------------------------------------
for cls in ("modal__overlay", "modal__dialog"):
    pos = sheet.base(cls).get("position")
    c.ok(
        pos in ("fixed", "absolute"),
        ".%s is positioned so its z-index applies -- got %r" % (cls, pos),
    )
c.eq(sheet.base("modal__overlay").get("inset"), "0", "the overlay still covers the viewport")

# --- the shell keeps everything that was not the bug ---------------------
shell = sheet.base("page-shell")
c.ok(W.same(shell.get("background"), "var(--shell)"), ".page-shell keeps its background")
c.ok(
    W.squash(shell.get("min-height")) in ("100vh", "100dvh"),
    ".page-shell keeps its min-height",
)

# --- the fix was not bought with !important ------------------------------
c.eq([(s, p) for s, p, _ in sheet.uses_important()], [], "no !important anywhere")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")

# --- the dialog content survived -----------------------------------------
buttons = doc.find_all("button", cls="modal__button")
c.eq(
    [n.stext() for n in buttons], ["Cancel", "Confirm"], "both actions are still there"
)
c.eq([n.attr("type") for n in buttons], ["button", "button"], "both actions keep type=button")
body = doc.find(cls="modal__body")
c.ok(body is not None and "EUR 1,188" in body.stext(), "the charge sentence is unchanged")

c.done()
