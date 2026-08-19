from datetime import date

from busdays import add_business_days, count_business_days, is_business_day

# n == 0 returns start unchanged, even on a weekend.
assert add_business_days(date(2024, 1, 6), 0) == date(2024, 1, 6)

# starting on a Saturday: the first business day forward is Monday.
assert add_business_days(date(2024, 1, 6), 1) == date(2024, 1, 8)
# ... and backwards is Friday.
assert add_business_days(date(2024, 1, 6), -1) == date(2024, 1, 5)

# crossing multiple weekends
assert add_business_days(date(2024, 1, 1), 10) == date(2024, 1, 15)

# holidays accepted as any iterable
assert add_business_days(date(2024, 1, 5), 1, {date(2024, 1, 8)}) == date(2024, 1, 9)
assert add_business_days(
    date(2024, 1, 5), 1, (date(2024, 1, 8), date(2024, 1, 9))
) == date(2024, 1, 10)

# empty and inverted ranges
assert count_business_days(date(2024, 1, 10), date(2024, 1, 10)) == 0
assert count_business_days(date(2024, 1, 20), date(2024, 1, 10)) == 0
# a weekend-only range
assert count_business_days(date(2024, 1, 6), date(2024, 1, 8)) == 0
# half-open: the end date is excluded
assert count_business_days(date(2024, 1, 8), date(2024, 1, 9)) == 1

assert is_business_day(date(2024, 1, 6), holidays=[]) is False

print("ok")
