"""Cart assembly.

Cart lines keep the SKU spelling the clerk first used; SKU comparison is
case-insensitive, so ``wid-1`` and ``WID-1`` land on the same line. The
catalog lookup downstream is case-insensitive as well.
"""


def new_cart():
    return {"lines": []}


def add_item(cart, sku, qty=1):
    """Add `qty` of `sku` to the cart, merging with an existing line for
    the same product (case-insensitive). Returns the cart."""
    if qty < 1:
        raise ValueError("qty must be at least 1")
    for line in cart["lines"]:
        if line["sku"].upper() == sku.upper():
            line["qty"] += qty
            return cart
    cart["lines"].append({"sku": sku, "qty": qty})
    return cart


def cart_quantities(cart):
    """{canonical_sku: total_qty} for reporting."""
    return {line["sku"].upper(): line["qty"] for line in cart["lines"]}
