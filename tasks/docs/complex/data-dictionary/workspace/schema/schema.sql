-- Kestrel billing schema, revision 12.
-- One file, four tables, no views. Every table carries a surrogate key
-- called id; nothing in the application ever relies on a natural key.
-- Money is stored in integer minor units, never as a decimal.

CREATE TABLE accounts (
    id BIGINT NOT NULL,
    name TEXT NOT NULL,
    country_code CHAR(2) NOT NULL,
    plan TEXT NOT NULL CHECK (plan IN ('standard', 'scale', 'enterprise')),
    seats INTEGER NOT NULL,
    legacy_ref TEXT,
    created_at TIMESTAMP NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE invoices (
    id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    number TEXT,
    status TEXT NOT NULL CHECK (status IN ('draft', 'approved', 'paid', 'void')),
    issued_on DATE,
    due_on DATE,
    total_cents BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (account_id) REFERENCES accounts (id)
);

CREATE TABLE invoice_lines (
    id BIGINT NOT NULL,
    invoice_id BIGINT NOT NULL,
    description TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price_cents BIGINT NOT NULL,
    line_kind TEXT NOT NULL CHECK (line_kind IN ('subscription', 'proration', 'credit')),
    PRIMARY KEY (id),
    FOREIGN KEY (invoice_id) REFERENCES invoices (id)
);

CREATE TABLE payments (
    id BIGINT NOT NULL,
    invoice_id BIGINT NOT NULL,
    received_on DATE NOT NULL,
    amount_cents BIGINT NOT NULL,
    method TEXT NOT NULL CHECK (method IN ('transfer', 'card', 'direct_debit')),
    reference TEXT,
    PRIMARY KEY (id),
    FOREIGN KEY (invoice_id) REFERENCES invoices (id)
);
