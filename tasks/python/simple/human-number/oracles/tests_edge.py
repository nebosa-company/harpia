from humanize import human_number

# rounding that crosses into the next unit bumps the unit
assert human_number(999999) == "1M"
assert human_number(999999999) == "1B"
assert human_number(999999999999) == "1T"
assert human_number(-999999) == "-1M"

# T is the ceiling: huge values stay in T
assert human_number(5000000000000000) == "5000T"
assert human_number(1500000000000000) == "1500T"

# plain .1f rounding, no surprises
assert human_number(1049) == "1K"
assert human_number(1051) == "1.1K"
assert human_number(43210) == "43.2K"

# boundaries
assert human_number(-999) == "-999"
assert human_number(-1000) == "-1K"

# results are strings
assert isinstance(human_number(7), str)
assert isinstance(human_number(70000), str)

print("ok")
