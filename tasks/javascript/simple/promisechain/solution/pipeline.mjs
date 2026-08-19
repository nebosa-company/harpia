// Stage pipeline for the enrichment worker: feed a value through a list of
// transformations, each of which may be synchronous or asynchronous.

export async function runPipeline(input, stages) {
  if (!Array.isArray(stages)) {
    throw new TypeError("stages must be an array");
  }
  let value = await input;
  for (const stage of stages) {
    if (typeof stage !== "function") {
      throw new TypeError("every stage must be a function");
    }
    value = await stage(value);
  }
  return value;
}

export function tap(fn) {
  if (typeof fn !== "function") {
    throw new TypeError("tap expects a function");
  }
  return async (value) => {
    await fn(value);
    return value;
  };
}
