"""Business-day arithmetic."""

from datetime import timedelta

_ONE = timedelta(days=1)


def is_business_day(day, holidays=()):
    return day.weekday() < 5 and day not in set(holidays)


def add_business_days(start, n, holidays=()):
    hol = set(holidays)
    if n == 0:
        return start
    step = _ONE if n > 0 else -_ONE
    remaining = abs(n)
    day = start
    while remaining > 0:
        day = day + step
        if day.weekday() < 5 and day not in hol:
            remaining -= 1
    return day


def count_business_days(start, end, holidays=()):
    hol = set(holidays)
    count = 0
    day = start
    while day < end:
        if day.weekday() < 5 and day not in hol:
            count += 1
        day = day + _ONE
    return count
