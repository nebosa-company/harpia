import tomllib

from ini2toml import convert


def roundtrip(ini):
    return tomllib.loads(convert(ini))


doc = roundtrip(
    "\n".join(
        [
            "title = demo",
            "count = 3",
            "",
            "[server]",
            "host = example.org",
            "port = 8080",
            "debug = true",
            "ratio = 1.5",
            "",
            "[client]",
            "retries = 0",
            "verbose = FALSE",
        ]
    )
)
assert doc == {
    "title": "demo",
    "count": 3,
    "server": {"host": "example.org", "port": 8080, "debug": True, "ratio": 1.5},
    "client": {"retries": 0, "verbose": False},
}, doc

# type inference details
doc = roundtrip(
    "\n".join(
        [
            "[types]",
            "a = -12",
            "b = +7",
            "c = 3.25",
            "d = -0.5",
            "e = TRUE",
            "f = false",
            "g = hello world",
            "h = 1.2.3",
            "i = 10e3",
        ]
    )
)
assert doc["types"] == {
    "a": -12,
    "b": 7,
    "c": 3.25,
    "d": -0.5,
    "e": True,
    "f": False,
    "g": "hello world",
    "h": "1.2.3",
    "i": "10e3",
}, doc["types"]
assert isinstance(doc["types"]["a"], int)
assert isinstance(doc["types"]["c"], float)

# comments, blank lines, whitespace
doc = roundtrip(
    "\n".join(
        [
            "; leading comment",
            "  # also a comment",
            "",
            "  [app]  ",
            "   name =   spaced out  ",
            "empty =",
        ]
    )
)
assert doc == {"app": {"name": "spaced out", "empty": ""}}, doc

print("ok")
