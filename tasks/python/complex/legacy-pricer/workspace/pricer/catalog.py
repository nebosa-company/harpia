"""Catalog loading and lookup.

The catalog CSV has a header row ``sku,name,price``; prices always carry
exactly two decimals (e.g. ``19.99``). SKUs are case-insensitive
throughout the system; their canonical form is uppercase. Prices are
handled in integer cents everywhere — the listed price must round-trip
exactly.
"""

import csv
import io


class CatalogError(Exception):
    pass


def load_catalog(csv_text):
    """Parse the catalog CSV into {canonical_sku: product} where product
    is {"sku", "name", "price_cents"}."""
    reader = csv.reader(io.StringIO(csv_text))
    header = next(reader, None)
    if header != ["sku", "name", "price"]:
        raise CatalogError(f"unexpected catalog header: {header!r}")
    catalog = {}
    for row in reader:
        if not row:
            continue
        if len(row) != 3:
            raise CatalogError(f"bad catalog row: {row!r}")
        sku, name, price = row[0].strip().upper(), row[1].strip(), row[2].strip()
        price_cents = int(float(price) * 100)
        catalog[sku] = {"sku": sku, "name": name, "price_cents": price_cents}
    return catalog


def get_product(catalog, sku):
    """Look up a product by SKU, case-insensitively. Raises CatalogError
    for a SKU that is not in the catalog."""
    if sku not in catalog:
        raise CatalogError(f"unknown sku: {sku}")
    return catalog[sku]
