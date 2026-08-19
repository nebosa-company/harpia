export function parseArgs(spec, argv) {
  const options = spec?.options ?? {};
  const shortMap = new Map();
  for (const [name, desc] of Object.entries(options)) {
    if (desc.short) shortMap.set(desc.short, name);
  }

  const values = {};
  const positionals = [];
  const multiSeen = new Set();

  const fail = (code, message) => {
    const e = new Error(message);
    e.code = code;
    throw e;
  };

  const setValue = (name, value) => {
    if (options[name].multiple) {
      if (!multiSeen.has(name)) {
        multiSeen.add(name);
        values[name] = [];
      }
      values[name].push(value);
    } else {
      values[name] = value;
    }
  };

  const coerce = (name, raw, token) => {
    const desc = options[name];
    if (desc.type === "number") {
      const n = Number(raw);
      if (String(raw).trim() === "" || !Number.isFinite(n)) {
        fail("INVALID_VALUE", `invalid number for ${token}: ${raw}`);
      }
      return n;
    }
    return raw;
  };

  let i = 0;
  let onlyPositionals = false;
  while (i < argv.length) {
    const arg = argv[i];

    if (onlyPositionals) {
      positionals.push(arg);
      i += 1;
      continue;
    }
    if (arg === "--") {
      onlyPositionals = true;
      i += 1;
      continue;
    }

    if (arg.startsWith("--")) {
      let body = arg.slice(2);
      let eqValue = null;
      const eq = body.indexOf("=");
      if (eq !== -1) {
        eqValue = body.slice(eq + 1);
        body = body.slice(0, eq);
      }

      if (Object.hasOwn(options, body)) {
        const desc = options[body];
        if (desc.type === "boolean") {
          if (eqValue !== null) {
            fail("INVALID_VALUE", `boolean option --${body} takes no value`);
          }
          setValue(body, true);
          i += 1;
          continue;
        }
        let raw;
        if (eqValue !== null) {
          if (eqValue === "" && desc.type === "number") {
            fail("MISSING_VALUE", `--${body}= is missing its value`);
          }
          raw = eqValue;
        } else {
          if (i + 1 >= argv.length) {
            fail("MISSING_VALUE", `--${body} needs a value`);
          }
          i += 1;
          raw = argv[i];
        }
        setValue(body, coerce(body, raw, `--${body}`));
        i += 1;
        continue;
      }

      if (body.startsWith("no-")) {
        const name = body.slice(3);
        if (Object.hasOwn(options, name)) {
          if (options[name].type !== "boolean") {
            fail("INVALID_VALUE", `--no-${name} negates a non-boolean option`);
          }
          if (eqValue !== null) {
            fail("INVALID_VALUE", `--no-${name} takes no value`);
          }
          setValue(name, false);
          i += 1;
          continue;
        }
      }

      fail("UNKNOWN_OPTION", `unknown option --${body}`);
    }

    if (arg.length > 1 && arg.startsWith("-")) {
      const letters = arg.slice(1);

      if (letters.length === 1) {
        const name = shortMap.get(letters);
        if (!name) fail("UNKNOWN_OPTION", `unknown option -${letters}`);
        const desc = options[name];
        if (desc.type === "boolean") {
          setValue(name, true);
          i += 1;
          continue;
        }
        if (i + 1 >= argv.length) {
          fail("MISSING_VALUE", `-${letters} needs a value`);
        }
        i += 1;
        setValue(name, coerce(name, argv[i], `-${letters}`));
        i += 1;
        continue;
      }

      for (const ch of letters) {
        const name = shortMap.get(ch);
        if (!name) fail("UNKNOWN_OPTION", `unknown option -${ch} in ${arg}`);
        if (options[name].type !== "boolean") {
          fail("MISSING_VALUE", `-${ch} cannot take a value inside a bundle`);
        }
        setValue(name, true);
      }
      i += 1;
      continue;
    }

    positionals.push(arg);
    i += 1;
  }

  for (const [name, desc] of Object.entries(options)) {
    if (Object.hasOwn(values, name)) continue;
    if (desc.multiple) {
      values[name] = desc.default !== undefined ? desc.default : [];
    } else if (desc.default !== undefined) {
      values[name] = desc.default;
    }
  }

  return { values, positionals };
}
