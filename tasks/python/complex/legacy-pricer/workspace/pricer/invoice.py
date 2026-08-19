"""Invoice assembly and rendering."""

from .catalog import get_product
from .discounts import bulk_discount_cents


def money(cents):
    """Format cents as $D.CC (no thousands separators)."""
    return f"${cents // 100}.{cents % 100:02d}"


def build_invoice(cart, catalog):
    """Price the cart. Returns a dict with:

    - "lines": [{"sku" (canonical), "name", "qty", "unit_cents",
                 "total_cents"} ...] in cart order
    - "subtotal_cents": sum of line totals
    - "discount_cents": total bulk discount
    - "total_cents": subtotal minus discounts
    """
    lines = []
    subtotal = 0
    discount = 0
    for cart_line in cart["lines"]:
        product = get_product(catalog, cart_line["sku"])
        qty = cart_line["qty"]
        unit = product["price_cents"]
        line_total = qty * unit
        subtotal += line_total
        discount += bulk_discount_cents(qty, unit)
        lines.append(
            {
                "sku": product["sku"],
                "name": product["name"],
                "qty": qty,
                "unit_cents": unit,
                "total_cents": line_total,
            }
        )
    return {
        "lines": lines,
        "subtotal_cents": subtotal,
        "discount_cents": discount,
        "total_cents": subtotal - discount,
    }


def format_invoice(inv):
    """Render the invoice as text: one line per item
    ("SKU xQTY Name $T.CC"), then "Subtotal", "Bulk discount" (only when
    non-zero), and "Total" lines. Lines joined with "\\n", trailing
    newline included."""
    out = []
    for line in inv["lines"]:
        out.append(
            f"{line['sku']} x{line['qty']} {line['name']} "
            f"{money(line['total_cents'])}"
        )
    out.append(f"Subtotal {money(inv['subtotal_cents'])}")
    if inv["discount_cents"]:
        out.append(f"Bulk discount -{money(inv['discount_cents'])}")
    out.append(f"Total {money(inv['total_cents'])}")
    return "\n".join(out) + "\n"
