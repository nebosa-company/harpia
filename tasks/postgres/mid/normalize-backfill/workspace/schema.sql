-- The wide table, exactly as it has been since the import script wrote it:
-- one row per order line, with the order and customer facts repeated.

CREATE TABLE orders_wide (
    order_ref        text NOT NULL,
    customer_email   text NOT NULL,
    customer_name    text NOT NULL,
    placed_on        date NOT NULL,
    status           text NOT NULL,
    line_no          integer NOT NULL,
    sku              text NOT NULL,
    quantity         integer NOT NULL,
    unit_price_cents integer NOT NULL,
    PRIMARY KEY (order_ref, line_no)
);

INSERT INTO orders_wide
    (order_ref, customer_email, customer_name, placed_on, status,
     line_no, sku, quantity, unit_price_cents) VALUES
    ('ORD-1001', 'rosa@example.com', 'Rosa Klein',  DATE '2024-02-03', 'shipped',   1, 'DESK-01',  1, 89900),
    ('ORD-1001', 'rosa@example.com', 'Rosa Klein',  DATE '2024-02-03', 'shipped',   2, 'LAMP-01',  2,  4900),
    ('ORD-1002', 'imre@example.org', 'Imre Bako',   DATE '2024-02-05', 'shipped',   1, 'CHAIR-01', 1, 34900),
    ('ORD-1003', 'rosa@example.com', 'Rosa Klein',  DATE '2024-02-11', 'placed',    1, 'MAT-01',   3,  7900),
    ('ORD-1003', 'rosa@example.com', 'Rosa Klein',  DATE '2024-02-11', 'placed',    2, 'LAMP-01',  1,  4900),
    ('ORD-1003', 'rosa@example.com', 'Rosa Klein',  DATE '2024-02-11', 'placed',    3, 'RISER-01', 2,  2900),
    ('ORD-1004', 'nadia@example.net','Nadia Farouk',DATE '2024-02-14', 'cancelled', 1, 'DESK-01',  1, 89900),
    ('ORD-1005', 'imre@example.org', 'Imre Bako',   DATE '2024-02-20', 'shipped',   1, 'RISER-01', 1,  2900),
    ('ORD-1005', 'imre@example.org', 'Imre Bako',   DATE '2024-02-20', 'shipped',   2, 'MAT-01',   1,  7900),
    ('ORD-1006', 'rosa@example.com', 'Rosa Klein',  DATE '2024-03-01', 'placed',    1, 'CHAIR-01', 2, 34900);
