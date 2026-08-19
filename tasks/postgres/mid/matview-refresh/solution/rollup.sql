-- The dashboard's rollup and the job that rebuilds it.
-- This file is applied immediately after schema.sql.

CREATE MATERIALIZED VIEW sales_rollup AS
SELECT o.region,
       count(DISTINCT o.id)::bigint AS orders,
       sum(i.amount_cents)::bigint  AS cents
FROM orders o
JOIN order_items i ON i.order_id = o.id
WHERE o.status <> 'cancelled'
GROUP BY o.region;

-- A concurrent refresh needs a unique index on the rollup's key.
CREATE UNIQUE INDEX sales_rollup_region ON sales_rollup (region);

CREATE FUNCTION refresh_sales_rollup() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY sales_rollup;
END;
$$;
