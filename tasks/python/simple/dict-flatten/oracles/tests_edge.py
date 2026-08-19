from flatten import flatten, unflatten

# custom separator
assert flatten({"a": {"b": 1}}, sep="/") == {"a/b": 1}
assert unflatten({"a/b": 1}, sep="/") == {"a": {"b": 1}}

# values that must stay leaves
assert flatten({"n": None, "z": 0, "e": {}}) == {"n": None, "z": 0, "e": {}}

# collision: a literal dotted key clashes with a produced path
try:
    flatten({"a": {"b": 1}, "a.b": 2})
except ValueError:
    pass
else:
    raise AssertionError("flatten collision should raise ValueError")

# unflatten conflict: leaf and prefix
try:
    unflatten({"a": 1, "a.b": 2})
except ValueError:
    pass
else:
    raise AssertionError("unflatten conflict should raise ValueError")

try:
    unflatten({"a.b": 2, "a": 1})
except ValueError:
    pass
else:
    raise AssertionError("unflatten conflict should raise ValueError")

# deep round trip with a multi-char separator
deep = {"a": {"b": {"c": {"d": 1}}}, "x": {"y": 2}}
assert unflatten(flatten(deep, sep="::"), sep="::") == deep

print("ok")
