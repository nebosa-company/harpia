// HS256 JWT sign/verify/decode on top of node:crypto.
// Exact claim, encoding, and error-code rules are in the project brief.

export function sign(payload, secret, options = {}) {
  throw new Error("not implemented");
}

export function verify(token, secret, options = {}) {
  throw new Error("not implemented");
}

export function decode(token) {
  throw new Error("not implemented");
}
