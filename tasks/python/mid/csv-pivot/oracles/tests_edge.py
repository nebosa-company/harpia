import csv
import io

from pivot import pivot

# mean
data = "team,stage,score\nred,one,4\nred,one,6\nblue,one,3\n"
out = pivot(data, "team", "stage", "score", aggregate="mean")
assert out == "team,one\nblue,3\nred,5\n", repr(out)

# quoted fields with embedded commas survive round-trip
tricky = (
    "vendor,month,total\n"
    '"Smith, Jones & Co",jan,10\n'
    '"Smith, Jones & Co",feb,20\n'
    "Acme,jan,5\n"
)
out = pivot(tricky, "vendor", "month", "total")
rows = list(csv.reader(io.StringIO(out)))
assert rows[0] == ["vendor", "feb", "jan"]
assert rows[1] == ["Acme", "", "5"]
assert rows[2] == ["Smith, Jones & Co", "20", "10"]
# the embedded comma forces quoting in the raw output
assert '"Smith, Jones & Co"' in out

# bad column names raise
base = "a,b,c\n1,2,3\n"
for args in [("nope", "b", "c"), ("a", "nope", "c"), ("a", "b", "nope")]:
    try:
        pivot(base, *args)
    except ValueError:
        pass
    else:
        raise AssertionError(f"pivot with {args} should raise ValueError")

# bad aggregate raises
try:
    pivot(base, "a", "b", "c", aggregate="median")
except ValueError:
    pass
else:
    raise AssertionError("unknown aggregate should raise ValueError")

# unparsable value for sum raises
try:
    pivot("a,b,c\nx,y,notanumber\n", "a", "b", "c")
except ValueError:
    pass
else:
    raise AssertionError("non-numeric value should raise ValueError")

# ... but count never parses values
out = pivot("a,b,c\nx,y,notanumber\n", "a", "b", "c", aggregate="count")
assert out == "a,y\nx,1\n", repr(out)

# single data row
out = pivot("i,c,v\nrow,col,7\n", "i", "c", "v")
assert out == "i,col\nrow,7\n", repr(out)

print("ok")
