// Money helpers. Everything is integer cents.

export function lineTotal(line) {
  return line.unitPrice * line.qty;
}

export function sumLines(lines) {
  return lines.reduce((sum, line) => sum + lineTotal(line), 0);
}

export function roundCents(value) {
  return Math.round(value);
}

export function discountFor(coupon, subtotal) {
  if (!coupon) return 0;
  if (coupon.kind === "percent") {
    return Math.min(subtotal, roundCents((subtotal * coupon.value) / 100));
  }
  if (coupon.kind === "amount") {
    return Math.min(subtotal, coupon.value);
  }
  return 0;
}
