// Fan-in for feed sources: start every read, then collect the outcomes.
export async function ingestAll(sources) {
  const settled = await Promise.allSettled(
    sources.map(async (s) => s.read()),
  );
  const ok = [];
  const failed = [];
  settled.forEach((result, i) => {
    const name = sources[i].name;
    if (result.status === "fulfilled") {
      ok.push({ name, value: result.value });
    } else {
      const reason = result.reason;
      failed.push({
        name,
        error: reason instanceof Error ? reason.message : String(reason),
      });
    }
  });
  return { ok, failed };
}
