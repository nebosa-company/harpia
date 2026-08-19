from wordfreq import word_freq, top_n

assert word_freq("") == []
assert word_freq("!!! ??? ...") == []
assert word_freq("   \t\n  ") == []

# underscore is a separator, not a word character
assert word_freq("foo_bar foo") == [("foo", 2), ("bar", 1)]

# digits count as word characters
assert word_freq("42 42 route66") == [("42", 2), ("route66", 1)]

# punctuation splits words
assert word_freq("end.start end") == [("end", 2), ("start", 1)]

assert top_n("a b c", 0) == []
assert top_n("a b c", -3) == []
assert top_n("a b c", 99) == [("a", 1), ("b", 1), ("c", 1)]
assert top_n("", 5) == []

print("ok")
