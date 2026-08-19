-- Reporting schema and a year of trading. Do not change this file.

CREATE TABLE customers (
    id     integer PRIMARY KEY,
    email  text NOT NULL,
    region text NOT NULL
);

CREATE TABLE orders (
    id          integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers (id),
    placed_at   timestamp NOT NULL,
    status      text NOT NULL
);

CREATE TABLE order_items (
    id               integer PRIMARY KEY,
    order_id         integer NOT NULL REFERENCES orders (id),
    sku              text NOT NULL,
    quantity         integer NOT NULL,
    unit_price_cents integer NOT NULL
);

INSERT INTO customers (id, email, region)
SELECT g, 'c' || g || '@example.com',
       (ARRAY['North', 'South', 'East', 'West'])[1 + (g % 4)]
FROM generate_series(1, 5000) g;

-- 60000 orders spread evenly over the 365 days of 2024.
INSERT INTO orders (id, customer_id, placed_at, status)
SELECT g,
       1 + ((g * 7) % 5000),
       TIMESTAMP '2024-01-01 00:00:00' + ((g % 365) || ' days')::interval
                                       + ((g % 24) || ' hours')::interval,
       CASE WHEN g % 23 = 0 THEN 'cancelled' ELSE 'shipped' END
FROM generate_series(1, 60000) g;

-- Three lines per order.
INSERT INTO order_items (id, order_id, sku, quantity, unit_price_cents)
SELECT (o.id * 3) + k,
       o.id,
       'SKU-' || ((o.id + k) % 40),
       1 + ((o.id + k) % 4),
       500 + (((o.id * 13) + k) % 900)
FROM orders o
CROSS JOIN generate_series(0, 2) k;

-- The indexes that hold up the foreign keys. Nothing indexes placed_at.
CREATE INDEX orders_customer_idx     ON orders (customer_id);
CREATE INDEX order_items_order_idx   ON order_items (order_id);
