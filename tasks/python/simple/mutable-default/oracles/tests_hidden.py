from inventory import merge_tags, new_item

# Independent records when no tags are passed.
a = new_item("a")
b = new_item("b")
assert a["tags"] == ["item"], a["tags"]
assert b["tags"] == ["item"], b["tags"]
assert a["tags"] is not b["tags"]

# Caller-supplied tags come first, followed by the automatic tag; the
# caller's list is untouched.
mine = ["fragile"]
rec = new_item("vase", mine)
assert rec["tags"] == ["fragile", "item"]
assert mine == ["fragile"]

# merge_tags appends only missing tags, in order.
rec2 = new_item("crate", ["wood"])
merge_tags(rec2, ["wood", "heavy", "item", "bulk"])
assert rec2["tags"] == ["wood", "item", "heavy", "bulk"]

print("ok")
