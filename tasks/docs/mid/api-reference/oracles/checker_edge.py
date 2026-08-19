"""Edge checks: signature, summary, parameters, returns and raises per symbol."""
import ast
import os
import sys


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def need(cond, msg):
    if not cond:
        fail(msg)


def read(path):
    need(os.path.isfile(path), "missing file: " + path)
    with open(path, encoding="utf-8") as fh:
        return fh.read().replace("\r\n", "\n").replace("\r", "\n")


def render_params(node):
    args = list(node.args.args)
    if args and args[0].arg in ("self", "cls"):
        args = args[1:]
    defaults = node.args.defaults
    first_default = len(args) - len(defaults)
    out = []
    for i, a in enumerate(args):
        s = a.arg
        if a.annotation is not None:
            s += ": " + ast.unparse(a.annotation)
        if i >= first_default:
            s += " = " + ast.unparse(defaults[i - first_default])
        out.append(s)
    return out


def param_list(node):
    args = list(node.args.args)
    if args and args[0].arg in ("self", "cls"):
        args = args[1:]
    return ["%s (%s)" % (a.arg,
                         ast.unparse(a.annotation) if a.annotation is not None else "-")
            for a in args]


def summary(node):
    doc = ast.get_docstring(node, clean=False)
    return doc.strip().split("\n")[0].strip() if doc else ""


def raises(node):
    doc = ast.get_docstring(node, clean=False) or ""
    out, inblock = [], False
    for l in doc.split("\n"):
        s = l.strip()
        if s == "Raises:":
            inblock = True
            continue
        if inblock and s:
            head = s.split(":", 1)
            if len(head) == 2 and head[0] and head[0][0].isupper() \
                    and head[0].replace("_", "").isalnum():
                out.append(head[0])
    return out


def collect(path):
    tree = ast.parse(read(path))
    syms = {}
    order = []
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and not node.name.startswith("_"):
            syms[node.name] = {
                "sig": "%s(%s) -> %s" % (node.name, ", ".join(render_params(node)),
                                         ast.unparse(node.returns)),
                "summary": summary(node),
                "params": param_list(node),
                "returns": ast.unparse(node.returns),
                "raises": raises(node),
            }
            order.append(node.name)
        elif isinstance(node, ast.ClassDef) and not node.name.startswith("_"):
            init = next((n for n in node.body if isinstance(n, ast.FunctionDef)
                         and n.name == "__init__"), None)
            if init is None:
                sig, params, rs = node.name + "()", [], []
            else:
                sig = "%s(%s)" % (node.name, ", ".join(render_params(init)))
                params, rs = param_list(init), raises(init)
            syms[node.name] = {"sig": sig, "summary": summary(node), "params": params,
                               "returns": "n/a", "raises": rs}
            order.append(node.name)
            for m in node.body:
                if isinstance(m, ast.FunctionDef) and not m.name.startswith("_"):
                    qn = node.name + "." + m.name
                    syms[qn] = {
                        "sig": "%s(%s) -> %s" % (qn, ", ".join(render_params(m)),
                                                 ast.unparse(m.returns)),
                        "summary": summary(m),
                        "params": param_list(m),
                        "returns": ast.unparse(m.returns),
                        "raises": raises(m),
                    }
                    order.append(qn)
    return syms, order


expected = {}
for root, _dirs, files in os.walk("src"):
    for f in sorted(files):
        if f.endswith(".py"):
            syms, _order = collect(os.path.join(root, f))
            expected.update(syms)
need(expected, "no public symbols found under src/")

doc = read("API_REFERENCE.md")
lines = [l.rstrip() for l in doc.split("\n")]

blocks = {}
cur = None
for l in lines:
    s = l.strip()
    if s.startswith("### "):
        cur = s[4:].strip()
        blocks[cur] = []
    elif s.startswith("## ") and not s.startswith("### "):
        cur = None
    elif cur is not None:
        blocks[cur].append(s)

for name, want in expected.items():
    need(name in blocks, "no entry for %s" % name)
    body = blocks[name]
    sig_lines = [b for b in body if b.startswith("`") and b.endswith("`") and len(b) > 2]
    need(sig_lines, "%s has no signature line in backticks" % name)
    got_sig = sig_lines[0][1:-1].strip()
    need(got_sig == want["sig"],
         "%s signature:\n  expected `%s`\n  got      `%s`" % (name, want["sig"], got_sig))

    bullets = {}
    for b in body:
        for key in ("Parameters", "Returns", "Raises"):
            if b.startswith("- " + key + ":"):
                bullets[key] = b.split(":", 1)[1].strip()
    for key in ("Parameters", "Returns", "Raises"):
        need(key in bullets, "%s is missing its '- %s:' line" % (name, key))

    want_params = ", ".join(want["params"]) if want["params"] else "none"
    need(bullets["Parameters"] == want_params,
         "%s parameters:\n  expected %r\n  got      %r"
         % (name, want_params, bullets["Parameters"]))
    need(bullets["Returns"] == want["returns"],
         "%s returns:\n  expected %r\n  got      %r"
         % (name, want["returns"], bullets["Returns"]))
    want_raises = ", ".join(want["raises"]) if want["raises"] else "none"
    need(bullets["Raises"] == want_raises,
         "%s raises:\n  expected %r\n  got      %r"
         % (name, want_raises, bullets["Raises"]))

    prose = [b for b in body if b and not b.startswith("- ")
             and not (b.startswith("`") and b.endswith("`"))]
    need(prose, "%s has no summary line" % name)
    need(prose[0] == want["summary"],
         "%s summary must be the first line of its docstring, verbatim:\n"
         "  expected %r\n  got      %r" % (name, want["summary"], prose[0]))

print("ok")
