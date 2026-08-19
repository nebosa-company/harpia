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
