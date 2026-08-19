import { createHmac, timingSafeEqual } from "node:crypto";

const b64url = (buf) => Buffer.from(buf).toString("base64url");

function hmac(input, secret) {
  return createHmac("sha256", secret).update(input).digest();
}

function makeError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

export function sign(payload, secret, options = {}) {
  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    throw new TypeError("sign: payload must be a plain object");
  }
  if (typeof secret !== "string" && !Buffer.isBuffer(secret)) {
    throw new TypeError("sign: secret must be a string or Buffer");
  }
  const { expiresIn, notBefore, now = Date.now } = options;
  const iat = Math.floor(now() / 1000);
  const claims = { ...payload, iat };
  if (expiresIn !== undefined) claims.exp = iat + expiresIn;
  if (notBefore !== undefined) claims.nbf = iat + notBefore;

  const header = { alg: "HS256", typ: "JWT" };
  const headerPart = b64url(JSON.stringify(header));
  const payloadPart = b64url(JSON.stringify(claims));
  const signingInput = `${headerPart}.${payloadPart}`;
  const signature = b64url(hmac(signingInput, secret));
  return `${signingInput}.${signature}`;
}

function parseParts(token) {
  if (typeof token !== "string") return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  let header;
  let payload;
  try {
    header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
    payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  } catch {
    return null;
  }
  if (typeof header !== "object" || header === null) return null;
  if (typeof payload !== "object" || payload === null) return null;
  return { header, payload, parts };
}

export function decode(token) {
  const parsed = parseParts(token);
  if (!parsed) return null;
  return { header: parsed.header, payload: parsed.payload };
}

export function verify(token, secret, options = {}) {
  const { now = Date.now } = options;
  const parsed = parseParts(token);
  if (!parsed) {
    throw makeError("ERR_JWT_MALFORMED", "malformed token");
  }
  const { header, payload, parts } = parsed;
  if (header.alg !== "HS256" || (header.typ !== undefined && header.typ !== "JWT")) {
    throw makeError("ERR_JWT_MALFORMED", "unsupported header");
  }
  const signingInput = `${parts[0]}.${parts[1]}`;
  const expected = hmac(signingInput, secret);
  let given;
  try {
    given = Buffer.from(parts[2], "base64url");
  } catch {
    throw makeError("ERR_JWT_SIGNATURE", "signature mismatch");
  }
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
    throw makeError("ERR_JWT_SIGNATURE", "signature mismatch");
  }
  const nowSec = Math.floor(now() / 1000);
  if (typeof payload.exp === "number" && nowSec >= payload.exp) {
    throw makeError("ERR_JWT_EXPIRED", "token expired");
  }
  if (typeof payload.nbf === "number" && nowSec < payload.nbf) {
    throw makeError("ERR_JWT_NOT_BEFORE", "token not yet valid");
  }
  return payload;
}
