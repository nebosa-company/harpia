-- Sales tables behind the rollup.

CREATE TABLE orders (
    id        integer PRIMARY KEY,
    region    text NOT NULL,
    status    text NOT NULL CHECK (status IN ('placed', 'shipped', 'cancelled')),
    placed_on date NOT NULL
);

CREATE TABLE order_items (
    id           integer PRIMARY KEY,
    order_id     integer NOT NULL REFERENCES orders (id),
    sku          text NOT NULL,
    amount_cents integer NOT NULL CHECK (amount_cents > 0)
);

INSERT INTO orders (id, region, status, placed_on) VALUES
    (1, 'North', 'shipped',   DATE '2024-05-02'),
    (2, 'North', 'placed',    DATE '2024-05-06'),
    (3, 'North', 'cancelled', DATE '2024-05-08'),
    (4, 'South', 'shipped',   DATE '2024-05-03'),
    (5, 'South', 'shipped',   DATE '2024-05-11'),
    (6, 'South', 'cancelled', DATE '2024-05-12'),
    (7, 'East',  'placed',    DATE '2024-05-15'),
    (8, 'East',  'cancelled', DATE '2024-05-19');

INSERT INTO order_items (id, order_id, sku, amount_cents) VALUES
    ( 1, 1, 'A-1', 10000),
    ( 2, 1, 'B-2',  5000),
    ( 3, 1, 'C-3',  2500),
    ( 4, 2, 'A-1', 20000),
    ( 5, 3, 'A-1', 99900),
    ( 6, 3, 'B-2', 11100),
    ( 7, 4, 'B-2',  7500),
    ( 8, 5, 'C-3',  3000),
    ( 9, 5, 'A-1', 12000),
    (10, 6, 'A-1', 40000),
    (11, 7, 'C-3',  6000),
    (12, 8, 'B-2', 80000);
