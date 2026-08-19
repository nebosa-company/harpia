"""Discount rules.

Bulk rule: a line of BULK_MIN_QTY or more units earns BULK_RATE percent
off that line's total (quantity times unit price), rounded down to whole
cents.

Coupons: apply_coupon(code, amount_cents) values a coupon against an
amount; unknown codes raise CouponError.
"""

BULK_MIN_QTY = 10
BULK_RATE = 10  # percent


class CouponError(Exception):
    pass


def bulk_discount_cents(qty, unit_cents):
    """The bulk discount for one line, in cents (0 when below the
    threshold)."""
    if qty < BULK_MIN_QTY:
        return 0
    return qty * unit_cents * BULK_RATE // 100


def apply_coupon(code, amount_cents):
    """The coupon's value in cents against `amount_cents`."""
    if code == "SAVE10":
        return amount_cents * 10 // 100
    if code == "TENOFF":
        return min(1000, amount_cents)
    raise CouponError(f"unknown coupon code: {code}")
