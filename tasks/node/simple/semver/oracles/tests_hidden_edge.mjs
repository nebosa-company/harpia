import test from "node:test";
import assert from "node:assert/strict";
import { parseVersion, compareVersions, sortVersions } from "./semver.mjs";

test("the semver.org precedence chain", () => {
  const chain = [
    "1.0.0-alpha",
    "1.0.0-alpha.1",
    "1.0.0-alpha.beta",
    "1.0.0-beta",
    "1.0.0-beta.2",
    "1.0.0-beta.11",
    "1.0.0-rc.1",
    "1.0.0",
  ];
  for (let i = 0; i < chain.length - 1; i++) {
    assert.equal(
      compareVersions(chain[i], chain[i + 1]),
      -1,
      `${chain[i]} < ${chain[i + 1]}`,
    );
    assert.equal(compareVersions(chain[i + 1], chain[i]), 1);
  }
});

test("build metadata is ignored", () => {
  assert.equal(compareVersions("1.0.0+build.1", "1.0.0+other"), 0);
  assert.equal(compareVersions("1.0.0-rc.1+a", "1.0.0-rc.1+b"), 0);
});

test("invalid versions throw", () => {
  const bad = [
    "1.2",
    "1.2.3.4",
    "01.0.0",
    "1.02.3",
    "1.2.3-01",
    "1.2.3-",
    "1.2.3-alpha..1",
    "1.2.3+",
    "a.b.c",
    "",
    "1.2.3-alpha_1",
  ];
  for (const v of bad) {
    assert.throws(
      () => parseVersion(v),
      (err) => err instanceof Error && err.message.startsWith("invalid version"),
      `expected throw for ${JSON.stringify(v)}`,
    );
  }
  assert.throws(() => parseVersion(123), /invalid version/);
});

test("numeric prerelease identifiers compare numerically", () => {
  assert.equal(compareVersions("1.0.0-alpha.9", "1.0.0-alpha.10"), -1);
  assert.equal(compareVersions("1.0.0-2", "1.0.0-11"), -1);
});

test("numeric identifiers sort before alphanumeric ones", () => {
  assert.equal(compareVersions("1.0.0-1", "1.0.0-a"), -1);
  assert.equal(compareVersions("1.0.0-11.z", "1.0.0-a"), -1);
});

test("sortVersions is stable and does not mutate", () => {
  const input = ["1.0.0+b", "1.0.0+a", "0.1.0"];
  const out = sortVersions(input);
  assert.deepEqual(out, ["0.1.0", "1.0.0+b", "1.0.0+a"]);
  assert.deepEqual(input, ["1.0.0+b", "1.0.0+a", "0.1.0"]);
});
