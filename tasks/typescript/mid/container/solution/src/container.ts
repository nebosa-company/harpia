/** A dependency container keyed by tokens that carry their service type. */
declare const SERVICE: unique symbol;

export type Token<T> = {
  readonly name: string;
  readonly [SERVICE]: T;
};

export interface Container {
  register<T>(token: Token<T>, factory: (c: Container) => T): Container;
  registerValue<T>(token: Token<T>, value: T): Container;
  has(token: Token<unknown>): boolean;
  resolve<T>(token: Token<T>): T;
  createScope(): Container;
}

export function token<T>(name: string): Token<T> {
  return { name } as Token<T>;
}

export function tokenName(token: Token<unknown>): string {
  return token.name;
}

type AnyToken = Token<unknown>;
type Factory = (c: Container) => unknown;

class Scope implements Container {
  private readonly factories = new Map<AnyToken, Factory>();
  private readonly instances = new Map<AnyToken, unknown>();
  private readonly building: AnyToken[] = [];

  constructor(private readonly parent: Scope | null) {}

  register<T>(token: Token<T>, factory: (c: Container) => T): Container {
    this.factories.set(token as AnyToken, factory as Factory);
    this.instances.delete(token as AnyToken);
    return this;
  }

  registerValue<T>(token: Token<T>, value: T): Container {
    return this.register(token, () => value);
  }

  has(token: Token<unknown>): boolean {
    return this.factories.has(token) || (this.parent?.has(token) ?? false);
  }

  private factoryFor(token: AnyToken): Factory | undefined {
    return this.factories.get(token) ?? this.parent?.factoryFor(token);
  }

  resolve<T>(token: Token<T>): T {
    const key = token as AnyToken;
    if (this.instances.has(key)) {
      return this.instances.get(key) as T;
    }
    const factory = this.factoryFor(key);
    if (factory === undefined) {
      throw new RangeError(`unregistered token: ${token.name}`);
    }
    if (this.building.includes(key)) {
      const chain = [...this.building, key].map((t) => t.name).join(" -> ");
      this.building.length = 0;
      throw new RangeError(`circular dependency: ${chain}`);
    }
    this.building.push(key);
    let value: unknown;
    try {
      value = factory(this);
    } finally {
      const at = this.building.lastIndexOf(key);
      if (at >= 0) this.building.splice(at, 1);
    }
    this.instances.set(key, value);
    return value as T;
  }

  createScope(): Container {
    return new Scope(this);
  }
}

export function createContainer(): Container {
  return new Scope(null);
}
