-- Catalogue schema and seed data.

CREATE TABLE products (
    id          integer PRIMARY KEY,
    sku         text NOT NULL UNIQUE,
    name        text NOT NULL,
    price_cents integer NOT NULL,
    archived_at timestamp
);

INSERT INTO products (id, sku, name, price_cents, archived_at) VALUES
    (1, 'DESK-01',  'Standing desk',       89900, NULL),
    (2, 'CHAIR-01', 'Task chair',          34900, NULL),
    (3, 'LAMP-01',  'Desk lamp',            4900, NULL),
    (4, 'MAT-01',   'Anti-fatigue mat',     7900, TIMESTAMP '2023-11-02 09:00:00'),
    (5, 'RISER-01', 'Monitor riser',        2900, TIMESTAMP '2024-01-15 16:30:00'),
    (6, 'SAMPLE-1', 'Fabric sample',           0, NULL);
