import re

import _webcheck as W

c = W.Check("form-validation/edge")
sheet = W.Sheet("form.css")
doc = W.parse_html("settings.html")

# --- nothing is painted before the user has typed ------------------------
BARE = re.compile(r"(?<![\w-]):invalid")
offenders = [
    sel for _, sel, _ in sheet.rules
    if BARE.search(sel) and ":placeholder-shown" not in sel
]
c.eq(offenders, [], "no rule keys off a bare :invalid without a placeholder guard")

# --- field wiring ---------------------------------------------------------
by_id = {}
for node in doc.walk():
    if node.attr("id"):
        by_id.setdefault(node.attr("id"), []).append(node)
c.eq(sorted(k for k, v in by_id.items() if len(v) > 1), [], "no duplicate ids")

FIELDS = [
    ("display-name", "text", True),
    ("email", "email", True),
    ("website", "url", False),
    ("postcode", "text", True),
]

fields = doc.find_all("div", cls="field")
c.eq(len(fields), 4, "four .field wrappers")

for i, (fid, kind, required) in enumerate(FIELDS):
    nodes = by_id.get(fid, [])
    if not c.eq(len(nodes), 1, "one control with id=%s" % fid):
        continue
    control = nodes[0]
    c.ok(control.has_class("field__input"), "%s carries class field__input" % fid)
    c.eq(control.attr("type"), kind, "%s input type" % fid)
    c.eq(control.has_attr("required"), required, "%s required flag" % fid)

    wrapper = control.parent
    c.ok(wrapper is not None and wrapper.has_class("field"), "%s sits in a .field" % fid)
    if wrapper is not None:
        c.eq(
            wrapper.has_class("field--required"),
            required,
            "%s wrapper carries field--required only when the field is required" % fid,
        )

    labels = [n for n in doc.find_all("label") if n.attr("for") == fid]
    c.eq(len(labels), 1, "one label for %s" % fid)
    if labels:
        c.ok(labels[0].has_class("field__label"), "%s label carries field__label" % fid)

    described = control.attr("aria-describedby")
    c.eq(described, "%s-error" % fid, "%s points at its error paragraph" % fid)
    targets = by_id.get(described or "", [])
    if c.eq(len(targets), 1, "one element with id=%s-error" % fid):
        c.ok(targets[0].has_class("field__error"), "%s-error is the .field__error" % fid)
        c.eq(targets[0].tag, "p", "%s-error is a <p>" % fid)

    # the error must follow the input inside the same wrapper, so the
    # sibling combinator in the stylesheet can reach it
    if wrapper is not None and targets:
        kids = wrapper.children
        if control in kids and targets[0] in kids:
            c.ok(
                kids.index(targets[0]) > kids.index(control),
                "%s error paragraph follows its input" % fid,
            )
        else:
            c.ok(False, "%s input and error are siblings" % fid)

# --- the pattern constraint survived --------------------------------------
postcode = by_id.get("postcode", [])
c.ok(
    bool(postcode) and postcode[0].attr("pattern") == "[0-9]{4} ?[A-Z]{2}",
    "the postcode pattern is unchanged",
)

# --- form chrome ----------------------------------------------------------
form = doc.find("form", cls="settings")
c.ok(form is not None, "the settings form is still there")
if form is not None:
    c.eq(form.attr("action"), "/account/settings", "form action")
    c.eq((form.attr("method") or "").lower(), "post", "form method")
buttons = doc.find_all("button")
c.eq([n.attr("type") for n in buttons], ["submit"], "one submit button")
c.eq(len(W.inline_styled(doc)), 0, "no inline style attributes")
c.eq(len(doc.find_all("script")), 0, "no <script> element")

c.done()
