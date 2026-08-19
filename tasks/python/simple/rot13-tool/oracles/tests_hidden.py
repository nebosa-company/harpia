from rot13 import rot13

assert rot13("Hello, World!") == "Uryyb, Jbeyq!"
assert rot13("abcdefghijklmnopqrstuvwxyz") == "nopqrstuvwxyzabcdefghijklm"
assert rot13("ABCDEFGHIJKLMNOPQRSTUVWXYZ") == "NOPQRSTUVWXYZABCDEFGHIJKLM"
assert rot13("") == ""
assert rot13("1234 !?.") == "1234 !?."
assert rot13("Why did the chicken?") == "Jul qvq gur puvpxra?"

# involution
for sample in ["Attack at dawn", "mixed CASE 42", "line1\nline2\n"]:
    assert rot13(rot13(sample)) == sample

# non-ASCII passes through
assert rot13("naïve café") == "anïir pnsé"

print("ok")
