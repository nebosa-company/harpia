import _webcheck as W

c = W.Check("accessible-form/core")
doc = W.parse_html("signup.html")

form = doc.find("form")
if not c.ok(form is not None, "the document has a <form>"):
    c.done()

c.eq(form.attr("action"), "/signup", "form action")
c.eq((form.attr("method") or "").lower(), "post", "form method")

labels = doc.find_all("label")
label_for = {}
for lab in labels:
    target = lab.attr("for")
    if target:
        label_for.setdefault(target, []).append(lab)

controls = {
    "full-name": ("input", "text", "Full name"),
    "email": ("input", "email", "Email address"),
    "password": ("input", "password", "Password"),
    "plan-basic": ("input", "radio", "Basic"),
    "plan-pro": ("input", "radio", "Pro"),
    "terms": ("input", "checkbox", None),
}

by_id = {}
for node in doc.walk():
    if node.attr("id"):
        by_id.setdefault(node.attr("id"), []).append(node)

for cid, (tag, kind, text) in sorted(controls.items()):
    nodes = by_id.get(cid, [])
    if not c.eq(len(nodes), 1, "exactly one element with id=%s" % cid):
        continue
    node = nodes[0]
    c.eq(node.tag, tag, "id=%s is an <%s>" % (cid, tag))
    c.eq((node.attr("type") or "").lower(), kind, "id=%s input type" % cid)
    owners = label_for.get(cid, [])
    c.eq(len(owners), 1, "exactly one <label for=%s>" % cid)
    if owners and text is not None:
        c.eq(owners[0].stext(), text, "label text for %s" % cid)

# --- required fields ------------------------------------------------------
for cid in ("full-name", "email", "password", "terms"):
    nodes = by_id.get(cid, [])
    c.ok(bool(nodes) and nodes[0].has_attr("required"), "%s is required" % cid)

# --- the plan radios are a labelled group ---------------------------------
fieldsets = doc.find_all("fieldset")
c.eq(len(fieldsets), 1, "one <fieldset> wraps the plan radios")
if fieldsets:
    fs = fieldsets[0]
    legends = fs.find_all("legend")
    c.eq(len(legends), 1, "the fieldset has one <legend>")
    if legends:
        c.eq(legends[0].stext(), "Plan", "legend text")
    radios = [n for n in fs.find_all("input") if (n.attr("type") or "").lower() == "radio"]
    c.eq(len(radios), 2, "both plan radios live inside the fieldset")

# --- submit ---------------------------------------------------------------
buttons = doc.find_all("button")
c.eq(len(buttons), 1, "one <button>")
if buttons:
    c.eq((buttons[0].attr("type") or "").lower(), "submit", "button type")
    c.eq(buttons[0].stext(), "Create account", "button text")

c.done()
