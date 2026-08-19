// Stage pipeline for the enrichment worker: feed a value through a list of
// transformations, each of which may be synchronous or asynchronous.

export function runPipeline(input, stages) {
  let chain = Promise.resolve(input);
  for (const stage of stages) {
    chain = chain.then((value) => {
      stage(value);
      return value;
    });
  }
  return chain;
}

export function tap(fn) {
  return (value) => {
    fn(value);
    return value;
  };
}
