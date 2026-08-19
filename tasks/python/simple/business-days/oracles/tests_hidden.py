from datetime import date

from busdays import add_business_days, count_business_days, is_business_day

# 2024-01-05 is a Friday, 2024-01-06 Saturday, 2024-01-08 Monday.
assert is_business_day(date(2024, 1, 5)) is True
assert is_business_day(date(2024, 1, 6)) is False
assert is_business_day(date(2024, 1, 7)) is False
assert is_business_day(date(2024, 1, 8)) is True
assert is_business_day(date(2024, 1, 8), holidays=[date(2024, 1, 8)]) is False

assert add_business_days(date(2024, 1, 5), 1) == date(2024, 1, 8)
assert add_business_days(date(2024, 1, 5), 2) == date(2024, 1, 9)
assert add_business_days(date(2024, 1, 5), 1, [date(2024, 1, 8)]) == date(2024, 1, 9)
assert add_business_days(date(2024, 1, 8), -1) == date(2024, 1, 5)
assert add_business_days(date(2024, 1, 1), 5) == date(2024, 1, 8)

# January 2024: 23 weekdays; [1st, 31st) covers days 1..30 -> 22 weekdays.
assert count_business_days(date(2024, 1, 1), date(2024, 1, 31)) == 22
assert count_business_days(
    date(2024, 1, 1), date(2024, 1, 31), holidays=[date(2024, 1, 1)]
) == 21
assert count_business_days(date(2024, 1, 8), date(2024, 1, 13)) == 5

print("ok")
