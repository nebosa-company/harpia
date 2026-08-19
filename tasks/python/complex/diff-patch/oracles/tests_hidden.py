import difflib

from difftool import PatchError, apply_patch, diff, revert


def reference(a, b):
    return "".join(
        difflib.unified_diff(
            a.splitlines(keepends=True),
            b.splitlines(keepends=True),
            fromfile="a",
            tofile="b",
        )
    )


PAIRS = [
    # (a, b)
    ("one\ntwo\nthree\n", "one\ntwo\nthree\n"),  # identical
    ("one\ntwo\nthree\n", "one\nTWO\nthree\n"),  # middle change
    ("alpha\nbeta\ngamma\ndelta\n", "alpha\nbeta\ngamma\ndelta\nepsilon\n"),  # append
    ("alpha\nbeta\ngamma\n", "intro\nalpha\nbeta\ngamma\n"),  # prepend
    ("a\nb\nc\nd\ne\nf\ng\nh\n", "a\nb\nc\nd\ne\nf\ng\nh\nzz\n"),
    ("a\nb\nc\nd\ne\nf\ng\nh\n", "a\nb\nc\nd\nf\ng\nh\n"),  # deletion
    ("", "brand\nnew\nfile\n"),  # from empty
    ("old\ncontent\n", ""),  # to empty
    # far-apart changes -> two hunks
    (
        "".join(f"line{i}\n" for i in range(1, 21)),
        "".join(
            ("CHANGED3\n" if i == 3 else "CHANGED17\n" if i == 17 else f"line{i}\n")
            for i in range(1, 21)
        ),
    ),
    # adjacent changes -> one hunk
    ("p\nq\nr\ns\nt\n", "p\nQ\nR\ns\nt\n"),
    # complete rewrite
    ("x\ny\n", "u\nv\nw\n"),
    # unicode
    ("café\nnaïve\n", "café\nNAÏVE\nextra\n"),
]

for a, b in PAIRS:
    d = diff(a, b)
    assert d == reference(a, b), f"diff format mismatch for {a!r} -> {b!r}:\n{d!r}"
    assert apply_patch(a, d) == b, f"apply failed for {a!r} -> {b!r}"

# identical inputs produce the empty patch
assert diff("same\n", "same\n") == ""
assert diff("", "") == ""

# empty patch applies to anything
assert apply_patch("anything\n", "") == "anything\n"
assert apply_patch("", "") == ""

# revert inverts every pair
for a, b in PAIRS:
    d = diff(a, b)
    assert revert(b, d) == a, f"revert failed for {a!r} -> {b!r}"
    assert revert(apply_patch(a, d), d) == a

print("ok")
