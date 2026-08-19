"""Compact number formatting."""

_UNITS = [(10**12, "T"), (10**9, "B"), (10**6, "M"), (10**3, "K")]


def human_number(n):
    sign = "-" if n < 0 else ""
    a = abs(n)
    if a < 1000:
        return f"{sign}{a}"
    idx = next(i for i, (unit, _) in enumerate(_UNITS) if a >= unit)
    while True:
        unit, suffix = _UNITS[idx]
        text = f"{a / unit:.1f}"
        if text == "1000.0" and idx > 0:
            idx -= 1
            continue
        break
    if text.endswith(".0"):
        text = text[:-2]
    return sign + text + suffix
