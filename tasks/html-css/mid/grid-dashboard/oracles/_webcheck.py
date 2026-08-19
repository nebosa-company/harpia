"""Structural helpers for the hidden checkers. Standard library only.

Parses HTML into a light element tree (``html.parser``) and stylesheets into
flat ``(conditions, selector, declarations)`` rules by brace matching. Nothing
here renders anything: every assertion built on top of it is about declared
structure, not painted pixels.
"""

import re
import sys
from html.parser import HTMLParser

VOID = {
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link",
    "meta", "param", "source", "track", "wbr",
}


# --------------------------------------------------------------------------
# HTML
# --------------------------------------------------------------------------

class Node(object):
    def __init__(self, tag, attrs=(), parent=None):
        self.tag = tag
        self.attrs = {}
        for key, val in attrs:
            self.attrs[key.lower()] = "" if val is None else val
        self.parent = parent
        self.parts = []

    @property
    def children(self):
        return [p for p in self.parts if isinstance(p, Node)]

    def attr(self, name, default=None):
        return self.attrs.get(name.lower(), default)

    def has_attr(self, name):
        return name.lower() in self.attrs

    def classes(self):
        return (self.attrs.get("class") or "").split()

    def has_class(self, name):
        return name in self.classes()

    def text(self):
        out = []
        for p in self.parts:
            out.append(p if isinstance(p, str) else p.text())
        return "".join(out)

    def stext(self):
        """Whitespace-collapsed text content."""
        return " ".join(self.text().split())

    def walk(self):
        for child in self.children:
            yield child
            for grand in child.walk():
                yield grand

    def find_all(self, tag=None, cls=None, **attrs):
        tags = None
        if tag is not None:
            tags = set(tag) if isinstance(tag, (set, tuple, list)) else {tag}
        out = []
        for node in self.walk():
            if tags is not None and node.tag not in tags:
                continue
            if cls is not None and not node.has_class(cls):
                continue
            good = True
            for key, want in attrs.items():
                key = key.rstrip("_").replace("_", "-")
                if want is True:
                    good = node.has_attr(key)
                elif want is False:
                    good = not node.has_attr(key)
                else:
                    good = node.attr(key) == want
                if not good:
                    break
            if good:
                out.append(node)
        return out

    def find(self, tag=None, cls=None, **attrs):
        got = self.find_all(tag, cls, **attrs)
        return got[0] if got else None

    def kids(self, tag=None, cls=None):
        out = []
        for child in self.children:
            if tag is not None and child.tag != tag:
                continue
            if cls is not None and not child.has_class(cls):
                continue
            out.append(child)
        return out

    def ancestors(self):
        node = self.parent
        while node is not None:
            yield node
            node = node.parent

    def ancestor_tags(self):
        return [a.tag for a in self.ancestors()]

    def __repr__(self):
        cls = " ".join(self.classes())
        return "<%s%s>" % (self.tag, (" ." + cls) if cls else "")


class _Builder(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self, convert_charrefs=True)
        self.root = Node("#document")
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.stack[-1])
        self.stack[-1].parts.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        node = Node(tag, attrs, self.stack[-1])
        self.stack[-1].parts.append(node)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        self.stack[-1].parts.append(data)


def read(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except (OSError, UnicodeDecodeError):
        return ""


def parse_html(path):
    builder = _Builder()
    builder.feed(read(path))
    builder.close()
    return builder.root


def head_of(doc):
    return doc.find("head") or Node("head")


def body_of(doc):
    return doc.find("body") or doc


def inline_styled(doc):
    """Elements carrying a non-empty style="" attribute."""
    return [n for n in doc.walk() if (n.attr("style") or "").strip()]


def ids(doc):
    return set(n.attr("id") for n in doc.walk() if n.attr("id"))


# --------------------------------------------------------------------------
# CSS
# --------------------------------------------------------------------------

NESTING_AT = ("@media", "@supports", "@layer", "@container", "@scope")


def strip_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


def squash(text):
    return re.sub(r"\s+", "", text or "").lower()


def norm_sel(sel):
    out = " ".join((sel or "").split())
    return re.sub(r"\s*([>+~])\s*", r" \1 ", out)


def _skip_string(text, i):
    """Index just past the string literal starting at `i`, or `i` itself."""
    quote = text[i]
    if quote not in "\"'":
        return i
    j = i + 1
    while j < len(text):
        if text[j] == "\\":
            j += 2
            continue
        if text[j] == quote:
            return j + 1
        j += 1
    return j


def _blocks(text):
    """Top-level ``(head, body)`` pairs; body is None for statement at-rules."""
    out = []
    i = 0
    start = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in "\"'":
            i = _skip_string(text, i)
            continue
        if ch == "{":
            depth = 1
            j = i + 1
            while j < n and depth:
                if text[j] in "\"'":
                    j = _skip_string(text, j)
                    continue
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                j += 1
            out.append((" ".join(text[start:i].split()), text[i + 1:j - 1]))
            i = j
            start = i
        elif ch == ";":
            head = text[start:i].strip()
            if head.startswith("@"):
                out.append((" ".join(head.split()), None))
            i += 1
            start = i
        else:
            i += 1
    return out


def _split_selectors(head):
    parts = []
    depth = 0
    buf = ""
    for ch in head:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(buf)
            buf = ""
        else:
            buf += ch
    parts.append(buf)
    return [norm_sel(p) for p in parts if p.strip()]


def rules(css):
    """Flatten a stylesheet to ``[(conditions, selector, body_text)]``."""
    out = []

    def walk(text, ctx):
        for head, body in _blocks(text):
            if body is None:
                continue
            if head.startswith("@"):
                word = head.split()[0].lower()
                if word in NESTING_AT:
                    walk(body, ctx + [head])
                else:
                    out.append((list(ctx), head, body))
            else:
                for sel in _split_selectors(head):
                    out.append((list(ctx), sel, body))

    walk(css, [])
    return out


def _add_decl(out, chunk):
    chunk = chunk.strip()
    if not chunk or ":" not in chunk:
        return
    prop, value = chunk.split(":", 1)
    prop = " ".join(prop.split()).lower()
    if not prop or " " in prop or "{" in prop:
        return
    out[prop] = " ".join(value.split())


def declarations(body):
    """Top-level ``prop -> value`` map of a rule body."""
    out = {}
    buf = []
    braces = 0
    parens = 0
    i = 0
    while i < len(body):
        ch = body[i]
        if ch in "\"'":
            end = _skip_string(body, i)
            buf.append(body[i:end])
            i = end
            continue
        i += 1
        if ch == "(":
            parens += 1
        elif ch == ")":
            parens = max(0, parens - 1)
        elif ch == "{":
            braces += 1
            buf = []
            continue
        elif ch == "}":
            braces = max(0, braces - 1)
            buf = []
            continue
        if braces == 0 and parens == 0 and ch == ";":
            _add_decl(out, "".join(buf))
            buf = []
        else:
            buf.append(ch)
    _add_decl(out, "".join(buf))
    return out


def specificity(sel):
    """(#id, .class/[attr]/:pseudo-class, type/::pseudo-element) counts."""
    sel = norm_sel(sel)
    pseudo_el = re.findall(r"::[a-zA-Z-]+", sel)
    rest = re.sub(r"::[a-zA-Z-]+", " ", sel)
    id_hits = re.findall(r"#[A-Za-z0-9_-]+", rest)
    rest = re.sub(r"#[A-Za-z0-9_-]+", " ", rest)
    attr_hits = re.findall(r"\[[^\]]*\]", rest)
    rest_no_attr = re.sub(r"\[[^\]]*\]", " ", rest)
    class_hits = re.findall(r"\.[A-Za-z0-9_-]+", rest_no_attr)
    pc_hits = re.findall(r":[a-zA-Z-]+", rest_no_attr)
    bare = re.sub(r"\.[A-Za-z0-9_-]+|:[a-zA-Z-]+(?:\([^)]*\))?", " ", rest_no_attr)
    type_hits = re.findall(r"(?<![\w-])[a-zA-Z][A-Za-z0-9-]*", bare)
    return (
        len(id_hits),
        len(class_hits) + len(attr_hits) + len(pc_hits),
        len(type_hits) + len(pseudo_el),
    )


HEX = re.compile(r"#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{1,5})?\b")


def sel_has_class(sel, name):
    """True iff `sel` uses `.name` as a whole class token (not a prefix)."""
    return bool(re.search(r"\." + re.escape(name) + r"(?![\w-])", sel or ""))


def sel_classes(sel):
    """Every class token used by a selector."""
    return re.findall(r"\.([A-Za-z_][A-Za-z0-9_-]*)", sel or "")


class Sheet(object):
    """A parsed stylesheet. ``cond=None`` means "top-level rules only"."""

    def __init__(self, path):
        self.path = path
        self.raw = read(path)
        self.css = strip_comments(self.raw)
        self.rules = rules(self.css)

    def exists(self):
        return bool(self.raw.strip())

    def _match_ctx(self, ctx, cond):
        if cond is None:
            return not ctx
        if cond == "ANY":
            return True
        needle = squash(cond)
        return any(needle in squash(c) for c in ctx)

    def all_rules(self, cond=None):
        out = []
        for ctx, sel, body in self.rules:
            if self._match_ctx(ctx, cond):
                out.append((sel, declarations(body)))
        return out

    def selectors(self, cond=None):
        return [sel for sel, _ in self.all_rules(cond)]

    def all_selectors(self):
        return [sel for _, sel, _ in self.rules]

    def decls_for(self, selector, cond=None):
        """Merged declarations of every rule with exactly this selector."""
        want = norm_sel(selector)
        merged = {}
        for sel, decls in self.all_rules(cond):
            if sel == want:
                merged.update(decls)
        return merged

    def value(self, selector, prop, cond=None):
        return self.decls_for(selector, cond).get(prop.lower())

    def has(self, selector, cond=None):
        want = norm_sel(selector)
        return any(sel == want for sel in self.selectors(cond))

    def matching(self, predicate, cond="ANY"):
        """Rules whose selector satisfies `predicate` (callable or substring).

        ``cond="ANY"`` searches every context, ``None`` only the top level.
        """
        out = []
        for ctx, sel, body in self.rules:
            if not self._match_ctx(ctx, cond):
                continue
            if callable(predicate):
                hit = predicate(sel)
            else:
                hit = squash(predicate) in squash(sel)
            if hit:
                out.append((ctx, sel, declarations(body)))
        return out

    def merged(self, needle, cond=None):
        """Declarations of every rule whose selector contains `needle`.

        Later rules win, as in the cascade. ``cond=None`` means top-level
        rules only; pass a media condition substring to look inside one.
        """
        out = {}
        for _, _, decls in self.matching(needle, cond):
            out.update(decls)
        return out

    def get(self, needle, prop, cond=None):
        return self.merged(needle, cond).get(prop.lower())

    def for_class(self, name, cond=None):
        """Merged declarations of rules using `.name` as a whole class token."""
        return self.merged(lambda s: sel_has_class(s, name), cond)

    def rules_for_class(self, name, cond="ANY"):
        return self.matching(lambda s: sel_has_class(s, name), cond)

    def base(self, name, cond=None):
        """Declarations of the plain `.name` rules: no combinator, no pseudo.

        This is the default state of a component, as opposed to the rules
        that key off :hover, :checked, a descendant combinator and so on.
        """

        def pred(sel):
            if not sel_has_class(sel, name):
                return False
            return not re.search(r"[ >+~:\[]", sel)

        return self.merged(pred, cond)

    def conditions(self):
        out = []
        for ctx, _, _ in self.rules:
            for c in ctx:
                if c not in out:
                    out.append(c)
        return out

    def has_condition(self, cond):
        needle = squash(cond)
        return any(needle in squash(c) for c in self.conditions())

    def at_rules(self, word):
        """[(head, declarations)] for non-nesting at-rules such as @page."""
        out = []
        needle = word.lower()
        for _, sel, body in self.rules:
            if sel.lower().startswith(needle):
                out.append((sel, body))
        return out

    def values(self, cond="ANY"):
        """Every declared (selector, prop, value) triple in the sheet."""
        out = []
        for ctx, sel, body in self.rules:
            if not self._match_ctx(ctx, cond):
                continue
            for prop, val in declarations(body).items():
                out.append((sel, prop, val))
        return out

    def hex_literals(self):
        out = []
        for sel, prop, val in self.values():
            for hit in HEX.findall(val):
                out.append((sel, prop, hit))
        return out

    def uses_important(self):
        return [(s, p, v) for s, p, v in self.values() if "!important" in v.lower()]


def areas(value):
    """grid-template-areas -> list of rows, each a list of area names."""
    rows = re.findall(r'"([^"]*)"', value or "")
    if not rows:
        rows = re.findall(r"'([^']*)'", value or "")
    return [r.split() for r in rows]


def tracks(value):
    """Count the tracks in a grid-template-columns/rows value."""
    val = " ".join((value or "").split())
    repeat = re.match(r"^repeat\(\s*(\d+)\s*,(.*)\)$", val)
    if repeat:
        inner = tracks(repeat.group(2))
        return int(repeat.group(1)) * (inner or 1)
    out = []
    depth = 0
    buf = ""
    for ch in val:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == " " and depth == 0:
            if buf:
                out.append(buf)
            buf = ""
        else:
            buf += ch
    if buf:
        out.append(buf)
    return len(out)


def numbers(value):
    """All numeric literals in a declaration value, as floats."""
    return [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", value or "")]


def clamp_args(value):
    """Split a top-level clamp(...) into its three raw arguments."""
    val = " ".join((value or "").split())
    match = re.match(r"^clamp\((.*)\)$", val)
    if not match:
        return None
    inner = match.group(1)
    parts = []
    depth = 0
    buf = ""
    for ch in inner:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(buf.strip())
            buf = ""
        else:
            buf += ch
    parts.append(buf.strip())
    return parts if len(parts) == 3 else None


def rem(value):
    """The rem magnitude of a single-unit length, or None."""
    match = re.match(r"^(-?\d+(?:\.\d+)?)rem$", " ".join((value or "").split()))
    return float(match.group(1)) if match else None


def same(a, b):
    """Whitespace-insensitive, case-insensitive value comparison."""
    return squash(a) == squash(b)


# --------------------------------------------------------------------------
# reporting
# --------------------------------------------------------------------------

class Check(object):
    def __init__(self, label):
        self.label = label
        self.n = 0
        self.fails = []

    def ok(self, cond, msg):
        self.n += 1
        if not cond:
            self.fails.append(msg)
        return bool(cond)

    def eq(self, got, want, msg):
        return self.ok(got == want, "%s -- got %r, want %r" % (msg, got, want))

    def done(self):
        for fail in self.fails:
            sys.stdout.write("FAIL: %s\n" % fail)
        if self.fails:
            sys.stdout.write(
                "%s: %d of %d checks failed\n" % (self.label, len(self.fails), self.n)
            )
            sys.exit(1)
        sys.stdout.write("%s: ok (%d checks)\n" % (self.label, self.n))
        sys.exit(0)
