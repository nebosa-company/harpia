import pricer
from pricer.cart import add_item, new_cart
from pricer.catalog import load_catalog
from pricer.discounts import CouponError, apply_coupon
from pricer.invoice import build_invoice, format_invoice

# coupon math
assert apply_coupon("SAVE10", 4088) == 408
assert apply_coupon("SAVE10", 99) == 9
assert apply_coupon("SAVE10", 0) == 0
assert apply_coupon("TENOFF", 5000) == 1000
assert apply_coupon("TENOFF", 700) == 700  # capped at the amount
try:
    apply_coupon("BOGUS", 1000)
except CouponError:
    pass
else:
    raise AssertionError("unknown coupon should raise CouponError")

# package re-exports
assert pricer.apply_coupon is apply_coupon
assert pricer.CouponError is CouponError

CSV = "sku,name,price\nWID-1,Widget,19.99\nBOLT-9,Bolt,0.10\n"
catalog = load_catalog(CSV)
cart = new_cart()
add_item(cart, "wid-1", 2)
add_item(cart, "BOLT-9", 10)

# coupon applies after the bulk discount
inv = build_invoice(cart, catalog, coupon="SAVE10")
assert inv["subtotal_cents"] == 4098
assert inv["discount_cents"] == 10
assert inv["coupon_cents"] == 408  # 10% of 4088
assert inv["coupon_code"] == "SAVE10"
assert inv["total_cents"] == 4098 - 10 - 408

# rendering with a coupon, exact layout
text = format_invoice(inv)
assert text == (
    "WID-1 x2 Widget $39.98\n"
    "BOLT-9 x10 Bolt $1.00\n"
    "Subtotal $40.98\n"
    "Bulk discount -$0.10\n"
    "Coupon (SAVE10) -$4.08\n"
    "Total $36.80\n"
), repr(text)

# no coupon: keys present, no coupon line rendered
inv2 = build_invoice(cart, catalog)
assert inv2["coupon_cents"] == 0
assert inv2["coupon_code"] is None
assert "Coupon" not in format_invoice(inv2)

# TENOFF capped by a small order
small = new_cart()
add_item(small, "BOLT-9", 3)  # 30 cents
inv3 = build_invoice(small, catalog, coupon="TENOFF")
assert inv3["coupon_cents"] == 30
assert inv3["total_cents"] == 0

print("ok")
