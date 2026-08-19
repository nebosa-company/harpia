from inventory import merge_tags, new_item

# Mutating one record's tags must not affect later records.
first = new_item("first")
first["tags"].append("later")
second = new_item("second")
assert second["tags"] == ["item"], second["tags"]

# Three defaulted records in a row stay independent.
records = [new_item(str(i)) for i in range(3)]
for rec in records:
    assert rec["tags"] == ["item"], rec["tags"]

# Explicit empty list behaves like the default, without aliasing the input.
supplied = []
rec = new_item("x", supplied)
assert rec["tags"] == ["item"]
assert supplied == []

# merge_tags with the default extra is a no-op and returns the record.
rec2 = new_item("y")
assert merge_tags(rec2) is rec2
assert rec2["tags"] == ["item"]

print("ok")
