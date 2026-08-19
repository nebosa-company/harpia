from difftool import PatchError, apply_patch, diff, revert

A = "".join(f"l{i}\n" for i in range(1, 11))
B = A.replace("l6\n", "six\n")
P = diff(A, B)

# applying to a drifted file: context mismatch must raise
drifted = A.replace("l5\n", "l5 drifted\n")
try:
    apply_patch(drifted, P)
except PatchError:
    pass
else:
    raise AssertionError("context mismatch must raise PatchError")

# deleted line mismatch
gone = A.replace("l6\n", "not l6\n")
try:
    apply_patch(gone, P)
except PatchError:
    pass
else:
    raise AssertionError("deletion mismatch must raise PatchError")

# garbage patches
for garbage in [
    "not a patch\n",
    "--- a\n",  # missing +++ line
    "--- a\n+++ b\n@@ nonsense @@\n",
    "--- a\n+++ b\n@@ -1,2 +1,2 @@\n?? what\n",
]:
    try:
        apply_patch(A, garbage)
    except PatchError:
        pass
    else:
        raise AssertionError(f"garbage patch should raise: {garbage!r}")

# hunk pointing past the end of the file
past = "--- a\n+++ b\n@@ -98,1 +98,1 @@\n-l98\n+nope\n"
try:
    apply_patch(A, past)
except PatchError:
    pass
else:
    raise AssertionError("out-of-range hunk should raise PatchError")

# out-of-order / overlapping hunks
overlap = (
    "--- a\n+++ b\n"
    "@@ -5,3 +5,3 @@\n l5\n-l6\n+six\n l7\n"
    "@@ -4,3 +4,3 @@\n l4\n-l5\n+five\n l6\n"
)
try:
    apply_patch(A, overlap)
except PatchError:
    pass
else:
    raise AssertionError("overlapping hunks should raise PatchError")

# text convention: non-empty inputs must end with a newline
for fn in [lambda: diff("no newline", "x\n"), lambda: diff("x\n", "no newline"),
           lambda: apply_patch("no newline", ""), lambda: revert("no newline", "")]:
    try:
        fn()
    except ValueError:
        pass
    else:
        raise AssertionError("missing trailing newline should raise ValueError")

# revert with the wrong base raises
a, b = "x\n", "y\n"
p = diff(a, b)
try:
    revert(a, p)  # p was never applied to a
except PatchError:
    pass
else:
    raise AssertionError("revert on the wrong base should raise PatchError")

# a change at the very first and very last line
first_last = diff("s\nm1\nm2\nm3\nm4\nm5\nm6\ne\n", "S\nm1\nm2\nm3\nm4\nm5\nm6\nE\n")
assert apply_patch("s\nm1\nm2\nm3\nm4\nm5\nm6\ne\n", first_last) == "S\nm1\nm2\nm3\nm4\nm5\nm6\nE\n"

# single-line file changes
assert apply_patch("only\n", diff("only\n", "lonely\n")) == "lonely\n"
assert revert("lonely\n", diff("only\n", "lonely\n")) == "only\n"

print("ok")
