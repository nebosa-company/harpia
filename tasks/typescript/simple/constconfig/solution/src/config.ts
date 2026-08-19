/** Environment table, and every union derived from it. */
export const ENVIRONMENTS = {
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
} as const;

type Table = typeof ENVIRONMENTS;

export type EnvironmentName = keyof Table;

export type Tier = Table[EnvironmentName]["tier"];

export type FeatureFlag = Table[EnvironmentName]["features"][number];

export type EnvironmentConfig<E extends EnvironmentName> = Table[E];

export const ENVIRONMENT_NAMES: readonly EnvironmentName[] = Object.keys(
  ENVIRONMENTS,
) as EnvironmentName[];

export function isEnvironmentName(value: unknown): value is EnvironmentName {
  return typeof value === "string" && Object.hasOwn(ENVIRONMENTS, value);
}

export function configFor<E extends EnvironmentName>(name: E): EnvironmentConfig<E> {
  if (!isEnvironmentName(name)) {
    throw new RangeError(`unknown environment: ${String(name)}`);
  }
  return ENVIRONMENTS[name];
}

export function hasFeature(name: EnvironmentName, flag: FeatureFlag): boolean {
  const features: readonly string[] = configFor(name).features;
  return features.includes(flag);
}

export function environmentsWithTier(tier: Tier): EnvironmentName[] {
  return ENVIRONMENT_NAMES.filter((name) => ENVIRONMENTS[name].tier === tier);
}
