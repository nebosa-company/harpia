"""Core checks: every public symbol documented once, in the right place."""
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


def public_symbols(path):
    tree = ast.parse(read(path))
    out = []
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and not node.name.startswith("_"):
            out.append(node.name)
        elif isinstance(node, ast.ClassDef) and not node.name.startswith("_"):
            out.append(node.name)
            for m in node.body:
                if isinstance(m, ast.FunctionDef) and not m.name.startswith("_"):
                    out.append(node.name + "." + m.name)
    return out


def private_symbols(path):
    tree = ast.parse(read(path))
    out = []
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and node.name.startswith("_"):
            out.append(node.name)
        elif isinstance(node, ast.ClassDef):
            for m in node.body:
                if isinstance(m, ast.FunctionDef) and m.name.startswith("_") \
                        and m.name != "__init__":
                    out.append(node.name + "." + m.name)
    return out


modules = {}
privates = {}
for root, _dirs, files in os.walk("src"):
    for f in sorted(files):
        if f.endswith(".py"):
            p = os.path.join(root, f)
            rel = os.path.relpath(p, "src").replace("\\", "/")
            dotted = rel[:-3].replace("/", ".")
            modules[dotted] = public_symbols(p)
            privates[dotted] = private_symbols(p)
need(modules, "no source modules found under src/")

doc = read("API_REFERENCE.md")
lines = [l.rstrip() for l in doc.split("\n")]
first = next((l.strip() for l in lines if l.strip()), "")
need(first == "# Kestrel API Reference",
     "the file must open with '# Kestrel API Reference', got " + repr(first))

got = []
cur_mod = None
for l in lines:
    s = l.strip()
    if s.startswith("## ") and not s.startswith("### "):
        cur_mod = s[3:].strip()
        got.append((cur_mod, []))
    elif s.startswith("### "):
        need(got, "a symbol entry appears before any module heading: " + s)
        got[-1][1].append(s[4:].strip())

want_mods = sorted(modules)
need([m for m, _ in got] == want_mods,
     "one level-2 section per module, in alphabetical order of the dotted "
     "name:\n  expected %r\n  got      %r" % (want_mods, [m for m, _ in got]))

for mod, syms in got:
    want = modules[mod]
    need(syms == want,
         "%s: every public symbol must be documented exactly once in source "
         "order:\n  expected %r\n  got      %r" % (mod, want, syms))
    for p in privates[mod]:
        need("### " + p not in doc,
             "%s.%s is private and must not be documented" % (mod, p))

print("ok")
