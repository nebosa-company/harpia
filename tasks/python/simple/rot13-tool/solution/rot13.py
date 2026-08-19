"""ROT13 text tool. CLI usage: python rot13.py INPUT OUTPUT"""

import sys

_LOWER = "abcdefghijklmnopqrstuvwxyz"
_UPPER = _LOWER.upper()
_TABLE = str.maketrans(
    _LOWER + _UPPER, _LOWER[13:] + _LOWER[:13] + _UPPER[13:] + _UPPER[:13]
)


def rot13(text):
    return text.translate(_TABLE)


def main(argv):
    if len(argv) != 2:
        print("usage: python rot13.py INPUT OUTPUT", file=sys.stderr)
        return 2
    src, dst = argv
    try:
        with open(src, "r", encoding="utf-8", newline="") as f:
            text = f.read()
    except OSError as e:
        print(f"cannot read {src}: {e}", file=sys.stderr)
        return 2
    with open(dst, "w", encoding="utf-8", newline="") as f:
        f.write(rot13(text))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
