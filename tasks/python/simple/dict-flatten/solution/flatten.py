"""Nested-dict flattening."""


def flatten(d, sep="."):
    out = {}

    def walk(prefix, node):
        for key, value in node.items():
            path = key if prefix is None else prefix + sep + key
            if isinstance(value, dict) and value:
                walk(path, value)
            else:
                if path in out:
                    raise ValueError(f"key collision on {path!r}")
                out[path] = value

    walk(None, d)
    return out


def unflatten(d, sep="."):
    out = {}
    for key, value in d.items():
        parts = key.split(sep)
        node = out
        for part in parts[:-1]:
            if part in node:
                if not isinstance(node[part], dict) or not node[part]:
                    raise ValueError(f"conflict at {part!r} in {key!r}")
            else:
                node[part] = {}
            node = node[part]
        leaf = parts[-1]
        if leaf in node:
            raise ValueError(f"conflict at {leaf!r} in {key!r}")
        node[leaf] = value
    return out
