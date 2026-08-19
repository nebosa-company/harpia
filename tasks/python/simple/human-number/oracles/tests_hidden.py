from humanize import human_number

assert human_number(0) == "0"
assert human_number(5) == "5"
assert human_number(999) == "999"
assert human_number(-42) == "-42"

assert human_number(1000) == "1K"
assert human_number(1500) == "1.5K"
assert human_number(12300) == "12.3K"
assert human_number(999000) == "999K"

assert human_number(1000000) == "1M"
assert human_number(2500000) == "2.5M"
assert human_number(1234567) == "1.2M"

assert human_number(1000000000) == "1B"
assert human_number(2500000000) == "2.5B"

assert human_number(1000000000000) == "1T"
assert human_number(1200000000000) == "1.2T"

assert human_number(-1500) == "-1.5K"
assert human_number(-2500000) == "-2.5M"

print("ok")
