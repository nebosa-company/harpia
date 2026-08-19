// Recipe resolution over the catalog service.

export function resolveRecipe(catalog, name, cb) {
  catalog.lookup(name, function (err, entry) {
    if (err) {
      cb(err);
      return;
    }
    var parts = entry.parts || [];
    var resolved = [];
    var total = entry.cost;
    var index = 0;
    function step() {
      if (index >= parts.length) {
        cb(null, { name: name, cost: total, parts: resolved });
        return;
      }
      var part = parts[index];
      index += 1;
      resolveRecipe(catalog, part, function (partErr, sub) {
        if (partErr) {
          cb(partErr);
          return;
        }
        resolved.push(sub);
        total += sub.cost;
        step();
      });
    }
    step();
  });
}

export function priceBasket(catalog, items, cb) {
  var lines = [];
  var total = 0;
  var index = 0;
  function next() {
    if (index >= items.length) {
      cb(null, { total: total, lines: lines });
      return;
    }
    var item = items[index];
    index += 1;
    catalog.lookup(item.name, function (err, entry) {
      if (err) {
        cb(err);
        return;
      }
      var subtotal = entry.cost * item.qty;
      total += subtotal;
      lines.push({ name: item.name, qty: item.qty, unit: entry.cost, subtotal: subtotal });
      next();
    });
  }
  next();
}

export function expandAll(catalog, name, cb) {
  catalog.lookup(name, function (err, entry) {
    if (err) {
      cb(err);
      return;
    }
    var names = [name];
    var parts = entry.parts || [];
    var index = 0;
    function step() {
      if (index >= parts.length) {
        cb(null, names);
        return;
      }
      var part = parts[index];
      index += 1;
      expandAll(catalog, part, function (partErr, sub) {
        if (partErr) {
          cb(partErr);
          return;
        }
        names = names.concat(sub);
        step();
      });
    }
    step();
  });
}
