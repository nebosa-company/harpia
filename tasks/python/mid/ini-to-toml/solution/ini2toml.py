"""INI -> TOML conversion."""

import json
import re

_INT = re.compile(r"^[+-]?\d+$")
_FLOAT = re.compile(r"^[+-]?\d+\.\d+$")


def _parse(ini_text):
    top = {}
    sections = {}
    current = top
    for raw in ini_text.split("\n"):
        line = raw.strip()
        if not line or line[0] in ";#":
            continue
        if line.startswith("[") and line.endswith("]"):
            name = line[1:-1]
            current = sections.setdefault(name, {})
            continue
        key, _, value = line.partition("=")
        current[key.strip()] = value.strip()
    return top, sections


def _typed(value):
    if value.lower() in ("true", "false"):
        return value.lower()
    if _INT.match(value):
        return str(int(value))
    if _FLOAT.match(value):
        return repr(float(value))
    return json.dumps(value)


def convert(ini_text):
    top, sections = _parse(ini_text)
    lines = []
    for key, value in top.items():
        lines.append(f"{key} = {_typed(value)}")
    for name, pairs in sections.items():
        if lines:
            lines.append("")
        lines.append(f"[{name}]")
        for key, value in pairs.items():
            lines.append(f"{key} = {_typed(value)}")
    return "\n".join(lines) + "\n"
