import _webcheck as W

c = W.Check("accessible-form/edge")
doc = W.parse_html("signup.html")

by_id = {}
for node in doc.walk():
    if node.attr("id"):
        by_id.setdefault(node.attr("id"), []).append(node)

dupes = sorted(k for k, v in by_id.items() if len(v) > 1)
c.eq(dupes, [], "no duplicate id values")

# --- hints are wired with aria-describedby --------------------------------
for field, hint, text in (
    ("email", "email-hint", "We only use this for account notices."),
    ("password", "password-hint", "At least 12 characters, including one number."),
):
    nodes = by_id.get(field, [])
    c.ok(
        bool(nodes) and nodes[0].attr("aria-describedby") == hint,
        "%s carries aria-describedby=%s" % (field, hint),
    )
    targets = by_id.get(hint, [])
    if c.eq(len(targets), 1, "one element with id=%s" % hint):
        c.eq(targets[0].tag, "p", "%s is a <p>" % hint)
        c.ok(targets[0].has_class("field__hint"), "%s has class field__hint" % hint)
        c.eq(targets[0].stext(), text, "%s text" % hint)

# --- autofill hints -------------------------------------------------------
for field, want in (
    ("full-name", "name"),
    ("email", "email"),
    ("password", "new-password"),
):
    nodes = by_id.get(field, [])
    c.ok(
        bool(nodes) and nodes[0].attr("autocomplete") == want,
        "%s has autocomplete=%s" % (field, want),
    )

# --- placeholders are not labels -----------------------------------------
placeheld = [n for n in doc.find_all("input") if n.has_attr("placeholder")]
c.eq([n.attr("id") or n.attr("name") for n in placeheld], [], "no placeholder attributes")

# --- radio group ----------------------------------------------------------
radios = [n for n in doc.find_all("input") if (n.attr("type") or "").lower() == "radio"]
c.eq(len(radios), 2, "exactly two radios")
c.eq(sorted(n.attr("name") or "" for n in radios), ["plan", "plan"], "radios share name=plan")
c.eq(sorted(n.attr("value") or "" for n in radios), ["basic", "pro"], "radio values")
checked = [n for n in radios if n.has_attr("checked")]
c.eq(len(checked), 1, "exactly one radio starts checked")
if checked:
    c.eq(checked[0].attr("value"), "basic", "the basic plan is preselected")

# --- terms label keeps its link ------------------------------------------
terms_labels = [n for n in doc.find_all("label") if n.attr("for") == "terms"]
if c.eq(len(terms_labels), 1, "one label for the terms checkbox"):
    anchors = terms_labels[0].find_all("a")
    c.eq([a.attr("href") for a in anchors], ["/terms"], "terms link kept inside the label")
    c.eq(terms_labels[0].stext(), "I accept the terms of service.", "terms label text")

# --- every control is labelled -------------------------------------------
label_targets = set(n.attr("for") for n in doc.find_all("label") if n.attr("for"))
unlabelled = []
for node in doc.find_all("input"):
    if (node.attr("type") or "").lower() == "hidden":
        continue
    cid = node.attr("id")
    if not cid or cid not in label_targets:
        unlabelled.append(node.attr("name") or "(unnamed)")
c.eq(unlabelled, [], "every input is reachable from a label's for attribute")

c.done()
