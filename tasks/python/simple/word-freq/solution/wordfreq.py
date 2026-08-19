"""Word frequency counting."""

import re

_WORD = re.compile(r"[a-z0-9]+")


def word_freq(text):
    counts = {}
    for word in _WORD.findall(text.lower()):
        counts[word] = counts.get(word, 0) + 1
    return sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))


def top_n(text, n):
    if n <= 0:
        return []
    return word_freq(text)[:n]
