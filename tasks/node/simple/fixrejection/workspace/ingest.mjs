// Fan-in for feed sources: start every read, then collect the outcomes.
export async function ingestAll(sources) {
  const pending = sources.map((s) => ({ name: s.name, promise: s.read() }));
  const ok = [];
  const failed = [];
  for (const entry of pending) {
    try {
      ok.push({ name: entry.name, value: await entry.promise });
    } catch (err) {
      failed.push({
        name: entry.name,
        error: err instanceof Error ? err.message : String(err),
      });
      break; // one source is down — stop early, no point draining the rest
    }
  }
  return { ok, failed };
}
