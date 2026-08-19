-- 001: the original schema, and the data as it stood when the incident hit.
-- This migration is fine and has always applied cleanly. Leave it alone.

CREATE TABLE customers (
    id    integer PRIMARY KEY,
    email text NOT NULL,
    name  text NOT NULL
);

CREATE TABLE orders (
    id          integer PRIMARY KEY,
    customer_id integer NOT NULL,
    placed_on   date NOT NULL,
    total_cents integer NOT NULL
);

CREATE TABLE payments (
    id           integer PRIMARY KEY,
    order_id     integer NOT NULL,
    amount_cents integer NOT NULL,
    method       text NOT NULL
);

INSERT INTO customers (id, email, name) VALUES
    (1, 'rosa@example.com',  'Rosa Klein'),
    (2, 'imre@example.org',  'Imre Bako'),
    (3, 'ROSA@Example.com',  'R. Klein'),
    (4, 'nadia@example.net', 'Nadia Farouk');

INSERT INTO orders (id, customer_id, placed_on, total_cents) VALUES
    (1,  1, DATE '2024-01-10', 12000),
    (2,  2, DATE '2024-01-15',  8000),
    (3,  3, DATE '2024-02-02', 15000),
    (4,  4, DATE '2024-02-20',  5000),
    (5,  3, DATE '2024-03-01',  9000),
    (6, 99, DATE '2024-03-05',  4000),
    (7,  1, DATE '2024-03-11',  7000);

INSERT INTO payments (id, order_id, amount_cents, method) VALUES
    (1,  1, 12000, 'card'),
    (2,  2,  8000, 'card'),
    (3,  3, 15000, 'transfer'),
    (4,  5,  9000, 'card'),
    (5, 88,  3000, 'card');
