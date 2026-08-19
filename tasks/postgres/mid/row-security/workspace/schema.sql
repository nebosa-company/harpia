-- Multi-tenant tables. Every row carries the tenant it belongs to.

CREATE TABLE tenants (
    id   integer PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE documents (
    id        integer PRIMARY KEY,
    tenant_id integer NOT NULL REFERENCES tenants (id),
    title     text NOT NULL,
    body      text NOT NULL
);

CREATE TABLE document_events (
    id          integer PRIMARY KEY,
    tenant_id   integer NOT NULL REFERENCES tenants (id),
    document_id integer NOT NULL REFERENCES documents (id),
    kind        text NOT NULL
);

INSERT INTO tenants (id, name) VALUES
    (1, 'Northwind'), (2, 'Umbrella'), (3, 'Cyberdyne');

INSERT INTO documents (id, tenant_id, title, body) VALUES
    (1, 1, 'Q1 plan',        'northwind internal'),
    (2, 1, 'Hiring loop',    'northwind internal'),
    (3, 2, 'Incident 44',    'umbrella internal'),
    (4, 2, 'Runbook',        'umbrella internal'),
    (5, 2, 'Retro',          'umbrella internal'),
    (6, 3, 'Model card',     'cyberdyne internal');

INSERT INTO document_events (id, tenant_id, document_id, kind) VALUES
    (1, 1, 1, 'created'),
    (2, 1, 1, 'shared'),
    (3, 2, 3, 'created'),
    (4, 2, 4, 'created'),
    (5, 3, 6, 'created');
