from tsvjoin import inner_join

# no trailing newline on the inputs is fine
out = inner_join("id\ta\n1\tx", "id\tb\n1\ty", "id")
assert out == "id\ta\tb\n1\tx\ty\n", repr(out)

# header-only right table -> header-only output
out2 = inner_join("id\ta\n1\tx\n", "id\tb\n", "id")
assert out2 == "id\ta\tb\n", repr(out2)

# fields may contain spaces
out3 = inner_join(
    "id\tname\n1\tAda Lovelace\n", "id\tcity\n1\tNew York\n", "id"
)
assert out3 == "id\tname\tcity\n1\tAda Lovelace\tNew York\n", repr(out3)

# missing key column raises
for l, r in [
    ("nope\ta\n1\tx\n", "id\tb\n1\ty\n"),
    ("id\ta\n1\tx\n", "nope\tb\n1\ty\n"),
]:
    try:
        inner_join(l, r, "id")
    except ValueError:
        pass
    else:
        raise AssertionError("missing key column should raise ValueError")

# ragged rows raise
for l, r in [
    ("id\ta\n1\n", "id\tb\n1\ty\n"),
    ("id\ta\n1\tx\n", "id\tb\n1\ty\tz\n"),
]:
    try:
        inner_join(l, r, "id")
    except ValueError:
        pass
    else:
        raise AssertionError("ragged row should raise ValueError")

# empty key values still join on exact equality
out4 = inner_join("id\ta\n\tx\n", "id\tb\n\ty\n", "id")
assert out4 == "id\ta\tb\n\tx\ty\n", repr(out4)

print("ok")
