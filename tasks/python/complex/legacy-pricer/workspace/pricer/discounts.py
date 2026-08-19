"""Discount rules.

Bulk rule: a line of BULK_MIN_QTY or more units earns BULK_RATE percent
off that line's total (quantity times unit price), rounded down to whole
cents.
"""

BULK_MIN_QTY = 10
BULK_RATE = 10  # percent


def bulk_discount_cents(qty, unit_cents):
    """The bulk discount for one line, in cents (0 when below the
    threshold)."""
    if qty < BULK_MIN_QTY:
        return 0
    return unit_cents * BULK_RATE // 100
