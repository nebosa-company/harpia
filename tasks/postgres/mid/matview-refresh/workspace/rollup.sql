-- The dashboard's rollup and the job that rebuilds it.
-- This file is applied immediately after schema.sql.

CREATE MATERIALIZED VIEW sales_rollup AS
SELECT o.region,
       count(*)::bigint              AS orders,
       sum(i.amount_cents)::bigint   AS cents
FROM orders o
JOIN order_items i ON i.order_id = o.id
GROUP BY o.region;

CREATE FUNCTION refresh_sales_rollup() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW sales_rollup;
END;
$$;
