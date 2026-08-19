-- Edge: the refresh must be the kind that leaves readers alone.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indrelid
    WHERE c.relname = 'sales_rollup' AND c.relkind = 'm' AND i.indisunique;
    IF n < 1 THEN
        RAISE EXCEPTION 'sales_rollup has no unique index, so it can only be refreshed by locking readers out';
    END IF;
END $$;

-- Proof the unique index is usable for a concurrent rebuild: this statement
-- fails outright when the rollup has none.
REFRESH MATERIALIZED VIEW CONCURRENTLY sales_rollup;

DO $$
DECLARE body text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO body
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'refresh_sales_rollup' AND n.nspname = 'public';
    IF body IS NULL THEN
        RAISE EXCEPTION 'refresh_sales_rollup is gone; the scheduled job calls it by name';
    END IF;
    IF upper(body) NOT LIKE '%CONCURRENTLY%' THEN
        RAISE EXCEPTION 'the scheduled refresh still rebuilds the rollup the blocking way';
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- A cancellation after the fact drops out of the numbers on the next refresh.
    UPDATE orders SET status = 'cancelled' WHERE id = 4;
    PERFORM refresh_sales_rollup();
    SELECT format('%s|%s', orders, cents) INTO got FROM sales_rollup WHERE region = 'South';
    IF got IS DISTINCT FROM '1|15000' THEN
        RAISE EXCEPTION 'after cancelling one South order the region reads %, expected 1|15000',
            coalesce(got, '<missing>');
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- An order counts once however many lines it carries.
    INSERT INTO orders (id, region, status, placed_on)
        VALUES (20, 'East', 'shipped', DATE '2024-06-01');
    INSERT INTO order_items (id, order_id, sku, amount_cents) VALUES
        (30, 20, 'A-1', 100), (31, 20, 'B-2', 200), (32, 20, 'C-3', 300), (33, 20, 'D-4', 400);
    PERFORM refresh_sales_rollup();
    SELECT format('%s|%s', orders, cents) INTO got FROM sales_rollup WHERE region = 'East';
    IF got IS DISTINCT FROM '2|7000' THEN
        RAISE EXCEPTION 'East reads %, expected 2|7000 (two orders, not five lines)',
            coalesce(got, '<missing>');
    END IF;
END $$;
