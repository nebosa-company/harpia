import {
  ENVIRONMENT_NAMES,
  configFor,
  environmentsWithTier,
  hasFeature,
  isEnvironmentName,
} from "../src/config";
import type {
  EnvironmentConfig,
  EnvironmentName,
  FeatureFlag,
  Tier,
} from "../src/config";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Names = Expect<Equals<EnvironmentName, "local" | "staging" | "prod">>;
type _Tiers = Expect<Equals<Tier, "dev" | "live">>;
type _Flags = Expect<Equals<FeatureFlag, "debugPanel" | "mockAuth">>;

type _Retries = Expect<Equals<EnvironmentConfig<"prod">["retries"], 5>>;
type _Url = Expect<Equals<EnvironmentConfig<"local">["apiUrl"], "http://localhost:4010">>;
type _StagingTier = Expect<Equals<EnvironmentConfig<"staging">["tier"], "dev">>;
type _StagingFeatures = Expect<
  Equals<EnvironmentConfig<"staging">["features"], readonly ["debugPanel"]>
>;
type _NamesConst = Expect<Equals<typeof ENVIRONMENT_NAMES, readonly EnvironmentName[]>>;
type _WithTier = Expect<Equals<ReturnType<typeof environmentsWithTier>, EnvironmentName[]>>;

const prod = configFor("prod");
type _ProdRetries = Expect<Equals<typeof prod.retries, 5>>;
type _ProdUrl = Expect<Equals<typeof prod.apiUrl, "https://api.example">>;

// @ts-expect-error "qa" is not in the table
configFor("qa");

// @ts-expect-error a bare string is not an environment name
configFor("prod" as string);

// @ts-expect-error "nope" is not a feature listed anywhere in the table
hasFeature("local", "nope");

// @ts-expect-error "qa" is not an environment name
hasFeature("qa", "debugPanel");

// @ts-expect-error "local" is an environment name, not a tier
environmentsWithTier("local");

// @ts-expect-error "beta" is not a tier in the table
environmentsWithTier("beta");

declare const raw: unknown;
if (isEnvironmentName(raw)) {
  const name: EnvironmentName = raw;
  void name;
  configFor(raw);
} else {
  // @ts-expect-error outside the guard the value is still unknown
  configFor(raw);
}

export type {
  _Names,
  _Tiers,
  _Flags,
  _Retries,
  _Url,
  _StagingTier,
  _StagingFeatures,
  _NamesConst,
  _WithTier,
  _ProdRetries,
  _ProdUrl,
};
