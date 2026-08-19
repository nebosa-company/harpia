// Virtual DOM over plain objects: build, render, diff, patch, serialize.

const VNODE = Symbol("vdom.vnode");

function isVNode(value) {
  return value !== null && typeof value === "object" && value[VNODE] === true;
}

function flatten(children, out) {
  for (const child of children) {
    if (Array.isArray(child)) {
      flatten(child, out);
      continue;
    }
    if (child === null || child === undefined || child === true || child === false) continue;
    if (typeof child === "number" || typeof child === "bigint") {
      out.push(String(child));
      continue;
    }
    if (typeof child === "string") {
      out.push(child);
      continue;
    }
    if (isVNode(child)) {
      out.push(child);
      continue;
    }
    throw new TypeError("unsupported child");
  }
  return out;
}

function checkChildren(children) {
  const elements = children.filter((c) => typeof c !== "string");
  const keyed = elements.filter((c) => c.key !== null);
  if (keyed.length > 0 && keyed.length !== children.length) {
    throw new Error("children must be all keyed or all unkeyed");
  }
  if (keyed.length > 0) {
    const seen = new Set();
    for (const child of keyed) {
      if (seen.has(child.key)) throw new Error(`duplicate key ${String(child.key)}`);
      seen.add(child.key);
    }
  }
}

export function h(type, props, ...children) {
  if (typeof type !== "string" || type.length === 0) {
    throw new TypeError("h expects a non-empty tag name");
  }
  const source = props === null || props === undefined ? {} : props;
  if (typeof source !== "object") throw new TypeError("props must be an object");
  const own = { ...source };
  let key = null;
  if ("key" in own) {
    const raw = own.key;
    delete own.key;
    if (raw !== null && raw !== undefined) {
      if (typeof raw !== "string" && typeof raw !== "number") {
        throw new TypeError("key must be a string or a number");
      }
      key = raw;
    }
  }
  const flat = flatten(children, []);
  checkChildren(flat);
  const node = { type, props: own, children: flat, key };
  Object.defineProperty(node, VNODE, { value: true });
  return node;
}

function attrsOf(props) {
  const attrs = {};
  for (const [name, value] of Object.entries(props)) {
    if (value === null || value === undefined || value === false) continue;
    attrs[name] = value;
  }
  return attrs;
}

export function render(vnode) {
  if (typeof vnode === "string") return vnode;
  if (!isVNode(vnode)) throw new TypeError("render expects a vnode");
  return {
    tag: vnode.type,
    attrs: attrsOf(vnode.props),
    children: vnode.children.map((child) => render(child)),
  };
}

function diffProps(oldProps, newProps, path, patches) {
  const before = attrsOf(oldProps);
  const after = attrsOf(newProps);
  const set = {};
  const remove = [];
  for (const [name, value] of Object.entries(after)) {
    if (!Object.is(before[name], value)) set[name] = value;
  }
  for (const name of Object.keys(before)) {
    if (!(name in after)) remove.push(name);
  }
  if (Object.keys(set).length > 0 || remove.length > 0) {
    patches.push({ op: "props", path, set, remove });
  }
}

function diffChildren(oldChildren, newChildren, path, patches) {
  const isKeyed = (list) => list.length > 0 && list.every((c) => typeof c !== "string" && c.key !== null);
  if (isKeyed(oldChildren) && isKeyed(newChildren)) {
    const work = oldChildren.slice();
    const newKeys = newChildren.map((c) => c.key);
    for (let i = work.length - 1; i >= 0; i--) {
      if (!newKeys.includes(work[i].key)) {
        patches.push({ op: "remove", path, index: i });
        work.splice(i, 1);
      }
    }
    for (let i = 0; i < newChildren.length; i++) {
      const wanted = newChildren[i];
      const at = work.findIndex((c) => c.key === wanted.key);
      if (at === -1) {
        patches.push({ op: "insert", path, index: i, node: render(wanted) });
        work.splice(i, 0, wanted);
        continue;
      }
      if (at !== i) {
        patches.push({ op: "move", path, from: at, to: i });
        const [moved] = work.splice(at, 1);
        work.splice(i, 0, moved);
      }
      diffNode(work[i], wanted, [...path, i], patches);
    }
    return;
  }

  const common = Math.min(oldChildren.length, newChildren.length);
  for (let i = 0; i < common; i++) {
    diffNode(oldChildren[i], newChildren[i], [...path, i], patches);
  }
  for (let i = oldChildren.length - 1; i >= common; i--) {
    patches.push({ op: "remove", path, index: i });
  }
  for (let i = common; i < newChildren.length; i++) {
    patches.push({ op: "insert", path, index: i, node: render(newChildren[i]) });
  }
}

function diffNode(oldNode, newNode, path, patches) {
  const oldIsText = typeof oldNode === "string";
  const newIsText = typeof newNode === "string";
  if (oldIsText && newIsText) {
    if (oldNode !== newNode) patches.push({ op: "text", path, value: newNode });
    return;
  }
  if (oldIsText !== newIsText || oldNode.type !== newNode.type) {
    patches.push({ op: "replace", path, node: render(newNode) });
    return;
  }
  diffProps(oldNode.props, newNode.props, path, patches);
  diffChildren(oldNode.children, newNode.children, path, patches);
}

export function diff(oldVNode, newVNode) {
  if (!isVNode(oldVNode) || !isVNode(newVNode)) {
    throw new TypeError("diff expects two element vnodes");
  }
  const patches = [];
  diffNode(oldVNode, newVNode, [], patches);
  return patches;
}

function resolve(root, path) {
  let node = root;
  for (const index of path) node = node.children[index];
  return node;
}

export function patch(host, patches) {
  if (host === null || typeof host !== "object") throw new TypeError("patch expects a host node");
  if (!Array.isArray(patches)) throw new TypeError("patch expects an array of operations");
  let root = host;
  for (const step of patches) {
    if (step.op === "replace") {
      if (step.path.length === 0) {
        root = step.node;
        continue;
      }
      const parent = resolve(root, step.path.slice(0, -1));
      parent.children[step.path[step.path.length - 1]] = step.node;
      continue;
    }
    if (step.op === "text") {
      const parent = resolve(root, step.path.slice(0, -1));
      parent.children[step.path[step.path.length - 1]] = step.value;
      continue;
    }
    const node = resolve(root, step.path);
    switch (step.op) {
      case "props":
        for (const name of step.remove ?? []) delete node.attrs[name];
        for (const [name, value] of Object.entries(step.set ?? {})) node.attrs[name] = value;
        break;
      case "insert":
        node.children.splice(step.index, 0, step.node);
        break;
      case "remove":
        node.children.splice(step.index, 1);
        break;
      case "move": {
        const [moved] = node.children.splice(step.from, 1);
        node.children.splice(step.to, 0, moved);
        break;
      }
      default:
        throw new TypeError(`unknown operation ${String(step.op)}`);
    }
  }
  return root;
}

function escapeText(text) {
  return text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

function escapeAttr(text) {
  return escapeText(text).replaceAll('"', "&quot;");
}

export function toHtml(host) {
  if (typeof host === "string") return escapeText(host);
  if (host === null || typeof host !== "object") throw new TypeError("toHtml expects a host node");
  let attrs = "";
  for (const [name, value] of Object.entries(host.attrs ?? {})) {
    attrs += ` ${name}="${escapeAttr(value === true ? "" : String(value))}"`;
  }
  const inner = (host.children ?? []).map((child) => toHtml(child)).join("");
  return `<${host.tag}${attrs}>${inner}</${host.tag}>`;
}
