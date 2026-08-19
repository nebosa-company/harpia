from tsvjoin import inner_join

left = "id\tname\n1\tAda\n2\tBob\n3\tCid\n"
right = "id\tcity\n2\tParis\n1\tOslo\n"
out = inner_join(left, right, "id")
assert out == "id\tname\tcity\n1\tAda\tOslo\n2\tBob\tParis\n", repr(out)

# multiple matches: cartesian, right-table order
left2 = "sku\tqty\nA\t2\nB\t5\n"
right2 = "sku\twarehouse\nA\teast\nA\twest\nB\tnorth\n"
out2 = inner_join(left2, right2, "sku")
assert out2 == (
    "sku\tqty\twarehouse\n"
    "A\t2\teast\n"
    "A\t2\twest\n"
    "B\t5\tnorth\n"
), repr(out2)

# key column not first; column order preserved around it
left3 = "name\tid\tage\nAda\t1\t36\n"
right3 = "city\tid\nOslo\t1\n"
out3 = inner_join(left3, right3, "id")
assert out3 == "id\tname\tage\tcity\n1\tAda\t36\tOslo\n", repr(out3)

# unmatched left rows are dropped
out4 = inner_join("id\tv\n9\tx\n", "id\tw\n1\ty\n", "id")
assert out4 == "id\tv\tw\n", repr(out4)

print("ok")
