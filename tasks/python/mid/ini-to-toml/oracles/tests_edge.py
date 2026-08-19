import tomllib

from ini2toml import convert


def roundtrip(ini):
    return tomllib.loads(convert(ini))


# strings that need escaping
doc = roundtrip(
    "\n".join(
        [
            "[paths]",
            r"root = C:\Users\svc\configs",
            'motd = say "hi" and \\ wave',
            "mixed = tab\\there",
        ]
    )
)
assert doc["paths"]["root"] == r"C:\Users\svc\configs", doc["paths"]["root"]
assert doc["paths"]["motd"] == 'say "hi" and \\ wave', doc["paths"]["motd"]
assert doc["paths"]["mixed"] == "tab\\there"

# value containing '=' splits on the first one only
doc = roundtrip("[q]\nformula = a=b=c")
assert doc["q"]["formula"] == "a=b=c"

# duplicate keys: last wins; duplicate sections merge
doc = roundtrip(
    "\n".join(
        [
            "[s]",
            "k = 1",
            "k = 2",
            "[t]",
            "a = 1",
            "[s]",
            "j = 9",
        ]
    )
)
assert doc == {"s": {"k": 2, "j": 9}, "t": {"a": 1}}, doc

# empty sections still appear
doc = roundtrip("[empty1]\n[full]\nx = 1\n[empty2]")
assert doc == {"empty1": {}, "full": {"x": 1}, "empty2": {}}, doc

# top-level only, and an entirely empty document
assert roundtrip("a = 1\nb = two") == {"a": 1, "b": "two"}
assert roundtrip("") == {}
assert roundtrip("\n; nothing here\n") == {}

# sign-only and dot-only values are strings, not numbers
doc = roundtrip("[w]\na = -\nb = .\nc = +.")
assert doc["w"] == {"a": "-", "b": ".", "c": "+."}

# numbers with surrounding spaces already trimmed
doc = roundtrip("[n]\nv =   42   ")
assert doc["n"]["v"] == 42

print("ok")
