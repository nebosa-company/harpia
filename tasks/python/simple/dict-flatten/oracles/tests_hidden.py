from flatten import flatten, unflatten

assert flatten({"a": {"x": 1, "y": {}}, "b": 2}) == {"a.x": 1, "a.y": {}, "b": 2}
assert flatten({}) == {}
assert flatten({"k": 1}) == {"k": 1}
assert flatten({"a": {"b": {"c": 3}}}) == {"a.b.c": 3}

# depth-first key order
out = flatten({"a": {"x": 1}, "b": 2, "c": {"d": {"e": 5}, "f": 6}})
assert list(out) == ["a.x", "b", "c.d.e", "c.f"]
assert out == {"a.x": 1, "b": 2, "c.d.e": 5, "c.f": 6}

# non-dict containers are leaves
assert flatten({"a": [1, {"b": 2}], "t": (3,)}) == {"a": [1, {"b": 2}], "t": (3,)}

assert unflatten({"a.x": 1, "a.y": {}, "b": 2}) == {"a": {"x": 1, "y": {}}, "b": 2}
assert unflatten({}) == {}
assert unflatten({"a.b.c": 3}) == {"a": {"b": {"c": 3}}}

# round trip
nested = {"server": {"host": "h", "opts": {"tls": True}}, "debug": False}
assert unflatten(flatten(nested)) == nested

print("ok")
