from pricer.cart import add_item, cart_quantities, new_cart
from pricer.catalog import CatalogError, get_product, load_catalog
from pricer.discounts import bulk_discount_cents
from pricer.invoice import build_invoice, format_invoice, money

CSV = "sku,name,price\nWID-1,Widget,19.99\nGAD-2,Gadget,5.00\nBOLT-9,Bolt,0.10\nTAPE-3,Tape,12.30\n"

catalog = load_catalog(CSV)

# listed prices round-trip to exact cents
assert catalog["WID-1"]["price_cents"] == 1999, catalog["WID-1"]["price_cents"]
assert catalog["GAD-2"]["price_cents"] == 500
assert catalog["BOLT-9"]["price_cents"] == 10
assert catalog["TAPE-3"]["price_cents"] == 1230, catalog["TAPE-3"]["price_cents"]

# case-insensitive lookup, canonical sku in the product
assert get_product(catalog, "wid-1")["price_cents"] == 1999
assert get_product(catalog, "WID-1")["name"] == "Widget"
assert get_product(catalog, "Wid-1")["sku"] == "WID-1"
try:
    get_product(catalog, "GHOST-0")
except CatalogError:
    pass
else:
    raise AssertionError("unknown sku should raise CatalogError")

# cart merging stays case-insensitive
cart = new_cart()
add_item(cart, "wid-1", 2)
add_item(cart, "WID-1", 1)
add_item(cart, "bolt-9", 10)
assert cart_quantities(cart) == {"WID-1": 3, "BOLT-9": 10}

# bulk discount is 10% of the LINE total
assert bulk_discount_cents(10, 10) == 10  # 10 bolts at $0.10 -> $0.10 off
assert bulk_discount_cents(9, 1000) == 0
assert bulk_discount_cents(10, 1999) == 1999  # 10 * 1999 // 10
assert bulk_discount_cents(25, 100) == 250

# end-to-end: lowercase skus price correctly
cart2 = new_cart()
add_item(cart2, "wid-1", 2)
add_item(cart2, "BOLT-9", 10)
inv = build_invoice(cart2, catalog)
assert inv["subtotal_cents"] == 2 * 1999 + 10 * 10
assert inv["discount_cents"] == 10
assert inv["total_cents"] == 3998 + 100 - 10
assert inv["lines"][0]["sku"] == "WID-1"
assert inv["lines"][0]["total_cents"] == 3998
assert inv["lines"][1]["sku"] == "BOLT-9"

# rendering (no coupon involved)
text = format_invoice(inv)
assert "WID-1 x2 Widget $39.98" in text
assert "BOLT-9 x10 Bolt $1.00" in text
assert "Subtotal $40.98" in text
assert "Bulk discount -$0.10" in text
assert text.rstrip().endswith("Total $40.88")

# money formatting
assert money(0) == "$0.00"
assert money(5) == "$0.05"
assert money(1999) == "$19.99"
assert money(123456) == "$1234.56"

print("ok")
