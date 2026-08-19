-- The reporting views. Same answers, without a per-row subquery.
-- This file is applied immediately after schema.sql.

CREATE VIEW customer_latest_order AS
SELECT c.id       AS customer_id,
       c.email    AS email,
       l.placed_at AS latest_placed_at,
       l.id       AS latest_order_id
FROM customers c
LEFT JOIN LATERAL (
    SELECT o.id, o.placed_at
    FROM orders o
    WHERE o.customer_id = c.id
    ORDER BY o.placed_at DESC, o.id DESC
    LIMIT 1
) l ON true;

-- The predicate now names the column itself, so an index on placed_at can
-- answer it; the window is the same half-open week.
CREATE VIEW march_orders AS
SELECT o.placed_at::date AS day,
       count(*)::bigint  AS orders
FROM orders o
WHERE o.placed_at >= TIMESTAMP '2024-03-01 00:00:00'
  AND o.placed_at <  TIMESTAMP '2024-03-08 00:00:00'
GROUP BY 1;

CREATE VIEW big_spenders AS
SELECT c.id    AS customer_id,
       c.email AS email,
       sum(i.quantity * i.unit_price_cents)::bigint AS total_cents
FROM customers c
JOIN orders      o ON o.customer_id = c.id AND o.status <> 'cancelled'
JOIN order_items i ON i.order_id = o.id
GROUP BY c.id, c.email
HAVING sum(i.quantity * i.unit_price_cents) > 95000;
