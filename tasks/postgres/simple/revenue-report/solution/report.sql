-- Reporting layer. Define the monthly_revenue view here.
-- This file is applied immediately after schema.sql.

CREATE VIEW monthly_revenue AS
SELECT date_trunc('month', o.placed_on)::date                            AS month,
       r.name                                                            AS region,
       count(DISTINCT o.id)::bigint                                      AS order_count,
       sum(i.quantity * i.unit_price_cents)::bigint                      AS gross_cents,
       sum(i.quantity * i.unit_price_cents - i.discount_cents)::bigint   AS net_cents
FROM orders o
JOIN customers   c ON c.id = o.customer_id
JOIN regions     r ON r.id = c.region_id
JOIN order_items i ON i.order_id = o.id
WHERE o.status <> 'cancelled'
GROUP BY 1, 2;
