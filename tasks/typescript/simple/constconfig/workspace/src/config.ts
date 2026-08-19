/**
 * Environment table.
 *
 * The data is settled. The types under it are placeholders: they widen
 * everything to `string`/`number`, so the table stops being a source of
 * truth the moment you leave this file.
 */
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
};

export type EnvironmentName = string;

export type Tier = string;

export type FeatureFlag = string;

export interface EnvironmentConfig<E extends EnvironmentName> {
  apiUrl: string;
  tier: string;
  retries: number;
  features: string[];
}

export const ENVIRONMENT_NAMES: readonly EnvironmentName[] = [];

export function isEnvironmentName(value: unknown): boolean {
  void value;
  throw new Error("isEnvironmentName is not implemented");
}

export function configFor<E extends EnvironmentName>(name: E): EnvironmentConfig<E> {
  void name;
  throw new Error("configFor is not implemented");
}

export function hasFeature(name: EnvironmentName, flag: FeatureFlag): boolean {
  void name;
  void flag;
  throw new Error("hasFeature is not implemented");
}

export function environmentsWithTier(tier: Tier): EnvironmentName[] {
  void tier;
  throw new Error("environmentsWithTier is not implemented");
}
