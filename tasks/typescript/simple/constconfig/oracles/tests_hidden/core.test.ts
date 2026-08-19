import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ENVIRONMENTS,
  ENVIRONMENT_NAMES,
  configFor,
  environmentsWithTier,
  hasFeature,
  isEnvironmentName,
} from "../src/config";

test("the table still holds the three environments unchanged", () => {
  assert.deepEqual(ENVIRONMENTS, {
    local: {
      apiUrl: "http://localhost:4010",
      tier: "dev",
      retries: 0,
      features: ["debugPanel", "mockAuth"],
    },
    staging: {
      apiUrl: "https://api.staging.example",
      tier: "dev",
      retries: 2,
      features: ["debugPanel"],
    },
    prod: {
      apiUrl: "https://api.example",
      tier: "live",
      retries: 5,
      features: [],
    },
  });
});

test("ENVIRONMENT_NAMES follows table order", () => {
  assert.deepEqual([...ENVIRONMENT_NAMES], ["local", "staging", "prod"]);
});

test("isEnvironmentName accepts the three names and nothing else", () => {
  assert.equal(isEnvironmentName("local"), true);
  assert.equal(isEnvironmentName("staging"), true);
  assert.equal(isEnvironmentName("prod"), true);
  assert.equal(isEnvironmentName("qa"), false);
  assert.equal(isEnvironmentName("Local"), false);
  assert.equal(isEnvironmentName(""), false);
  assert.equal(isEnvironmentName(1), false);
  assert.equal(isEnvironmentName(null), false);
  assert.equal(isEnvironmentName(undefined), false);
  assert.equal(isEnvironmentName({}), false);
  assert.equal(isEnvironmentName("toString"), false, "prototype keys are not names");
  assert.equal(isEnvironmentName("constructor"), false);
});

test("configFor hands back the table's own entry", () => {
  assert.equal(configFor("prod"), ENVIRONMENTS.prod);
  assert.equal(configFor("local"), ENVIRONMENTS.local);
  assert.equal(configFor("staging").retries, 2);
});

test("configFor refuses a name that is not in the table", () => {
  const sneaky = "qa" as unknown as "prod";
  assert.throws(
    () => configFor(sneaky),
    (err: unknown) =>
      err instanceof RangeError && err.message === "unknown environment: qa",
  );
});

test("hasFeature reads the entry's feature list", () => {
  assert.equal(hasFeature("local", "debugPanel"), true);
  assert.equal(hasFeature("local", "mockAuth"), true);
  assert.equal(hasFeature("staging", "debugPanel"), true);
  assert.equal(hasFeature("staging", "mockAuth"), false);
  assert.equal(hasFeature("prod", "debugPanel"), false);
  assert.equal(hasFeature("prod", "mockAuth"), false);
});

test("environmentsWithTier groups by tier in table order", () => {
  assert.deepEqual(environmentsWithTier("dev"), ["local", "staging"]);
  assert.deepEqual(environmentsWithTier("live"), ["prod"]);
});
