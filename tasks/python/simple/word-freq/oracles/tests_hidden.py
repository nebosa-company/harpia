from wordfreq import word_freq, top_n

assert word_freq("the cat and the hat") == [("the", 2), ("and", 1), ("cat", 1), ("hat", 1)]
assert word_freq("Dog dog DOG") == [("dog", 3)]
assert word_freq("a1 a1 b2") == [("a1", 2), ("b2", 1)]
assert word_freq("it's") == [("it", 1), ("s", 1)]
assert word_freq("b a c b a b") == [("b", 3), ("a", 2), ("c", 1)]

# ties broken by word ascending
assert word_freq("pear apple pear apple mango") == [
    ("apple", 2),
    ("pear", 2),
    ("mango", 1),
]

assert top_n("b a c b a b", 2) == [("b", 3), ("a", 2)]
assert top_n("b a c b a b", 1) == [("b", 3)]

print("ok")
