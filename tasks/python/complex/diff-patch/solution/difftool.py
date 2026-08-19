"""Unified diff / patch tools."""

import difflib
import re


class PatchError(Exception):
    pass


_HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def _check_text(text):
    if text and not text.endswith("\n"):
        raise ValueError("non-empty text must end with a newline")


def diff(a, b):
    _check_text(a)
    _check_text(b)
    return "".join(
        difflib.unified_diff(
            a.splitlines(keepends=True),
            b.splitlines(keepends=True),
            fromfile="a",
            tofile="b",
        )
    )


def _parse_hunks(patch):
    """Yield (old_index, old_len, new_index, new_len, body_lines)."""
    lines = patch.splitlines(keepends=True)
    if len(lines) < 2 or not lines[0].startswith("--- ") or not lines[1].startswith("+++ "):
        raise PatchError("patch must start with ---/+++ headers")
    hunks = []
    i = 2
    while i < len(lines):
        m = _HUNK.match(lines[i])
        if m is None:
            raise PatchError(f"expected hunk header, got {lines[i]!r}")
        old_disp = int(m.group(1))
        old_len = int(m.group(2)) if m.group(2) is not None else 1
        new_disp = int(m.group(3))
        new_len = int(m.group(4)) if m.group(4) is not None else 1
        old_index = old_disp - 1 if old_len > 0 else old_disp
        new_index = new_disp - 1 if new_len > 0 else new_disp
        i += 1
        body = []
        consumed_old = 0
        consumed_new = 0
        while i < len(lines) and consumed_old + consumed_new < old_len + new_len:
            line = lines[i]
            tag = line[:1]
            if tag == " ":
                consumed_old += 1
                consumed_new += 1
            elif tag == "-":
                consumed_old += 1
            elif tag == "+":
                consumed_new += 1
            else:
                raise PatchError(f"invalid hunk line {line!r}")
            body.append(line)
            i += 1
        if consumed_old != old_len or consumed_new != new_len:
            raise PatchError("hunk body does not match its header counts")
        hunks.append((old_index, old_len, new_index, new_len, body))
    return hunks


def _apply(text, patch, forward):
    _check_text(text)
    if patch == "":
        return text
    src = text.splitlines(keepends=True)
    out = []
    pos = 0  # next unconsumed line of src
    del_tag, add_tag = ("-", "+") if forward else ("+", "-")
    for old_index, old_len, new_index, new_len, body in _parse_hunks(patch):
        if not forward:
            old_index, new_index = new_index, old_index
            old_len, new_len = new_len, old_len
        if old_index < pos:
            raise PatchError("hunks overlap or are out of order")
        if old_index > len(src):
            raise PatchError("hunk start past the end of the text")
        out.extend(src[pos:old_index])
        pos = old_index
        if len(out) != new_index:
            raise PatchError("hunk positions are inconsistent")
        for line in body:
            tag, content = line[:1], line[1:]
            if tag == " ":
                if pos >= len(src) or src[pos] != content:
                    raise PatchError(f"context mismatch at line {pos + 1}")
                out.append(content)
                pos += 1
            elif tag == del_tag:
                if pos >= len(src) or src[pos] != content:
                    raise PatchError(f"mismatch on removed line at {pos + 1}")
                pos += 1
            elif tag == add_tag:
                out.append(content)
            else:  # pragma: no cover - _parse_hunks already validated tags
                raise PatchError(f"invalid hunk line {line!r}")
    out.extend(src[pos:])
    return "".join(out)


def apply_patch(text, patch):
    return _apply(text, patch, forward=True)


def revert(text, patch):
    return _apply(text, patch, forward=False)
