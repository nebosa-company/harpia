-- Accounts and the audit table compliance asked for. The audit table is
-- created empty and must be filled by the database, not by the application.

CREATE TABLE accounts (
    id            integer PRIMARY KEY,
    name          text NOT NULL,
    status        text NOT NULL CHECK (status IN ('open', 'frozen', 'closed')),
    balance_cents integer NOT NULL
);

CREATE TABLE account_audit (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id integer NOT NULL,
    action     text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_row    jsonb,
    new_row    jsonb,
    changed_by text NOT NULL,
    changed_at timestamptz NOT NULL
);

INSERT INTO accounts (id, name, status, balance_cents) VALUES
    (1, 'Operating',  'open',   1250000),
    (2, 'Payroll',    'open',    840000),
    (3, 'Escrow',     'frozen',  500000);
