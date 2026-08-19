import test from "node:test";
import assert from "node:assert/strict";
import { parseVersion, compareVersions, sortVersions } from "./semver.mjs";

test("numeric core comparison", () => {
  assert.equal(compareVersions("1.2.3", "1.2.4"), -1);
  assert.equal(compareVersions("2.0.0", "1.9.9"), 1);
  assert.equal(compareVersions("1.2.3", "1.2.3"), 0);
  assert.equal(compareVersions("1.10.0", "1.9.0"), 1);
});

test("leading v is accepted and equal", () => {
  assert.equal(compareVersions("v1.2.3", "1.2.3"), 0);
});

test("prerelease sorts before the release", () => {
  assert.equal(compareVersions("1.0.0-alpha", "1.0.0"), -1);
  assert.equal(compareVersions("1.0.0", "1.0.0-rc.1"), 1);
});

test("parseVersion structure", () => {
  assert.deepEqual(parseVersion("v1.2.3-alpha.1+linux.001"), {
    major: 1,
    minor: 2,
    patch: 3,
    prerelease: ["alpha", 1],
    build: ["linux", "001"],
  });
  assert.deepEqual(parseVersion("0.0.0"), {
    major: 0,
    minor: 0,
    patch: 0,
    prerelease: [],
    build: [],
  });
});

test("sortVersions ascending", () => {
  const input = ["1.0.0", "0.9.9", "1.0.0-alpha", "2.0.0", "1.2.0"];
  assert.deepEqual(sortVersions(input), [
    "0.9.9",
    "1.0.0-alpha",
    "1.0.0",
    "1.2.0",
    "2.0.0",
  ]);
});
