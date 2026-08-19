-- The reporting views. Correct, and far slower than they need to be.
-- This file is applied immediately after schema.sql.

CREATE VIEW customer_latest_order AS
SELECT c.id    AS customer_id,
       c.email AS email,
       (SELECT max(o.placed_at)
        FROM orders o
        WHERE o.customer_id = c.id) AS latest_placed_at,
       (SELECT o.id
        FROM orders o
        WHERE o.customer_id = c.id
        ORDER BY o.placed_at DESC, o.id DESC
        LIMIT 1) AS latest_order_id
FROM customers c;

CREATE VIEW march_orders AS
SELECT date_trunc('day', o.placed_at)::date AS day,
       count(*)::bigint                     AS orders
FROM orders o
WHERE date_trunc('day', o.placed_at)
      BETWEEN TIMESTAMP '2024-03-01 00:00:00' AND TIMESTAMP '2024-03-07 00:00:00'
GROUP BY 1;

CREATE VIEW big_spenders AS
SELECT c.id    AS customer_id,
       c.email AS email,
       (SELECT coalesce(sum(i.quantity * i.unit_price_cents), 0)
        FROM orders o
        JOIN order_items i ON i.order_id = o.id
        WHERE o.customer_id = c.id AND o.status <> 'cancelled')::bigint AS total_cents
FROM customers c
WHERE (SELECT coalesce(sum(i.quantity * i.unit_price_cents), 0)
       FROM orders o
       JOIN order_items i ON i.order_id = o.id
       WHERE o.customer_id = c.id AND o.status <> 'cancelled') > 95000;
