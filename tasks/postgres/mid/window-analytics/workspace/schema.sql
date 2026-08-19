-- Sales schema and seed data for the analytics layer.

CREATE TABLE reps (
    id     integer PRIMARY KEY,
    name   text NOT NULL,
    region text NOT NULL
);

CREATE TABLE sales (
    id           integer PRIMARY KEY,
    rep_id       integer NOT NULL REFERENCES reps (id),
    sold_on      date NOT NULL,
    amount_cents integer NOT NULL CHECK (amount_cents > 0)
);

CREATE TABLE price_updates (
    id           integer PRIMARY KEY,
    sku          text NOT NULL,
    effective_on date NOT NULL,
    price_cents  integer NOT NULL,
    source       text NOT NULL
);

INSERT INTO reps (id, name, region) VALUES
    (1, 'Ana Duarte',   'North'),
    (2, 'Ben Ostrom',   'North'),
    (3, 'Cleo Nakata',  'North'),
    (4, 'Dov Hersch',   'South'),
    (5, 'Eli Barron',   'East'),
    (6, 'Fay Adeyemi',  'East');

INSERT INTO sales (id, rep_id, sold_on, amount_cents) VALUES
    ( 1, 1, DATE '2024-04-01', 20000),
    ( 2, 1, DATE '2024-04-03', 20000),
    ( 3, 1, DATE '2024-04-09', 10000),
    ( 4, 2, DATE '2024-04-01', 15000),
    ( 5, 2, DATE '2024-04-12', 35000),
    ( 6, 3, DATE '2024-04-03', 20000),
    ( 7, 4, DATE '2024-04-02', 12000),
    ( 8, 4, DATE '2024-04-02',  8000),
    ( 9, 4, DATE '2024-04-18', 10000),
    (10, 6, DATE '2024-04-05', 12000);

INSERT INTO price_updates (id, sku, effective_on, price_cents, source) VALUES
    (1, 'A-1', DATE '2024-01-01',  1000, 'launch'),
    (2, 'A-1', DATE '2024-03-01',  1200, 'quarterly'),
    (3, 'A-1', DATE '2024-06-01',  1300, 'quarterly'),
    (4, 'A-1', DATE '2024-06-01',  1250, 'correction'),
    (5, 'B-2', DATE '2024-02-15',  4500, 'launch'),
    (6, 'C-3', DATE '2024-05-20',   900, 'launch'),
    (7, 'C-3', DATE '2024-05-01',   950, 'backfill');
