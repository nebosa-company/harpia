// Request body helpers.

export class BodyError extends Error {
  constructor(message) {
    super(message);
    this.statusCode = 400;
  }
}

export async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString("utf8");
  try {
    return JSON.parse(raw);
  } catch {
    throw new BodyError("invalid json body");
  }
}
