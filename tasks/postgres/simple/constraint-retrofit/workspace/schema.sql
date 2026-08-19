-- Billing schema. seed.sql is applied straight after this file.

CREATE TABLE plans (
    code          text PRIMARY KEY,
    monthly_cents integer NOT NULL
);

CREATE TABLE subscriptions (
    id           integer PRIMARY KEY,
    account_ref  text NOT NULL,
    plan_code    text NOT NULL REFERENCES plans (code),
    seats        integer NOT NULL,
    started_on   date NOT NULL,
    ended_on     date,
    status       text NOT NULL,
    discount_pct numeric(5, 2) NOT NULL DEFAULT 0
);
