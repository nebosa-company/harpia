-- Reference schema and seed data for the sales database.
-- This file describes the tables the reporting layer reads from.

CREATE TABLE regions (
    id   integer PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE customers (
    id        integer PRIMARY KEY,
    name      text NOT NULL,
    region_id integer NOT NULL REFERENCES regions (id)
);

CREATE TABLE orders (
    id          integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers (id),
    placed_on   date NOT NULL,
    status      text NOT NULL CHECK (status IN ('placed', 'shipped', 'cancelled'))
);

CREATE TABLE order_items (
    id               integer PRIMARY KEY,
    order_id         integer NOT NULL REFERENCES orders (id),
    sku              text NOT NULL,
    quantity         integer NOT NULL CHECK (quantity > 0),
    unit_price_cents integer NOT NULL CHECK (unit_price_cents >= 0),
    discount_cents   integer NOT NULL DEFAULT 0 CHECK (discount_cents >= 0)
);

INSERT INTO regions (id, name) VALUES
    (1, 'North'), (2, 'South'), (3, 'East');

INSERT INTO customers (id, name, region_id) VALUES
    (1, 'Ada Lindqvist', 1),
    (2, 'Bo Ferreira',   1),
    (3, 'Cy Nakamura',   2),
    (4, 'Di Okonkwo',    2),
    (5, 'Eve Marchetti', 3);

INSERT INTO orders (id, customer_id, placed_on, status) VALUES
    ( 1, 1, DATE '2024-01-05', 'shipped'),
    ( 2, 2, DATE '2024-01-19', 'placed'),
    ( 3, 3, DATE '2024-01-22', 'shipped'),
    ( 4, 1, DATE '2024-02-02', 'cancelled'),
    ( 5, 4, DATE '2024-02-11', 'shipped'),
    ( 6, 5, DATE '2024-02-14', 'shipped'),
    ( 7, 2, DATE '2024-02-28', 'shipped'),
    ( 8, 3, DATE '2024-03-03', 'placed'),
    ( 9, 5, DATE '2024-03-17', 'cancelled'),
    (10, 1, DATE '2024-03-30', 'shipped');

INSERT INTO order_items (id, order_id, sku, quantity, unit_price_cents, discount_cents) VALUES
    ( 1, 1, 'A-1', 2,  5000,    0),
    ( 2, 1, 'B-2', 1,  2500,  500),
    ( 3, 2, 'A-1', 3,  5000, 1000),
    ( 4, 3, 'C-3', 1, 12000,    0),
    ( 5, 4, 'A-1', 10, 5000,    0),
    ( 6, 5, 'B-2', 4,  2500,  250),
    ( 7, 6, 'C-3', 2, 12000, 2000),
    ( 8, 7, 'A-1', 1,  5000,    0),
    ( 9, 7, 'C-3', 1, 12000, 1200),
    (10, 8, 'B-2', 6,  2500,    0);
