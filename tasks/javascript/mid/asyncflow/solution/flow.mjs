// Recipe resolution over the catalog service.

function lookup(catalog, name) {
  return new Promise((resolve, reject) => {
    catalog.lookup(name, (err, entry) => {
      if (err) reject(err);
      else resolve(entry);
    });
  });
}

export async function resolveRecipe(catalog, name) {
  const entry = await lookup(catalog, name);
  const parts = [];
  let cost = entry.cost;
  for (const part of entry.parts ?? []) {
    const sub = await resolveRecipe(catalog, part);
    parts.push(sub);
    cost += sub.cost;
  }
  return { name, cost, parts };
}

export async function priceBasket(catalog, items) {
  const distinct = [...new Set(items.map((item) => item.name))];
  const entries = await Promise.all(distinct.map((name) => lookup(catalog, name)));
  const byName = new Map(distinct.map((name, i) => [name, entries[i]]));

  const lines = items.map((item) => {
    const unit = byName.get(item.name).cost;
    return { name: item.name, qty: item.qty, unit, subtotal: unit * item.qty };
  });
  const total = lines.reduce((sum, line) => sum + line.subtotal, 0);
  return { total, lines };
}

export async function* expand(catalog, name) {
  const entry = await lookup(catalog, name);
  yield name;
  for (const part of entry.parts ?? []) {
    yield* expand(catalog, part);
  }
}
