// Bearer-token check for every route.

export function checkAuth(req, tokens) {
  const header = req.headers.authorization ?? "";
  if (!header.startsWith("Bearer ")) return false;
  return tokens.includes(header.slice("Bearer ".length));
}
