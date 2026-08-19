-- Billing schema. seed.sql is applied straight after this file.

CREATE TABLE plans (
    code          text PRIMARY KEY,
    monthly_cents integer NOT NULL CHECK (monthly_cents >= 0)
);

CREATE TABLE subscriptions (
    id           integer PRIMARY KEY,
    account_ref  text NOT NULL CHECK (btrim(account_ref) <> ''),
    plan_code    text NOT NULL REFERENCES plans (code),
    seats        integer NOT NULL CHECK (seats BETWEEN 1 AND 500),
    started_on   date NOT NULL,
    ended_on     date,
    status       text NOT NULL CHECK (status IN ('trialing', 'active', 'paused', 'cancelled')),
    discount_pct numeric(5, 2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100),
    CONSTRAINT subscriptions_period_ordered CHECK (ended_on IS NULL OR ended_on >= started_on)
);

CREATE UNIQUE INDEX subscriptions_one_live_per_account
    ON subscriptions (account_ref)
    WHERE status <> 'cancelled';
