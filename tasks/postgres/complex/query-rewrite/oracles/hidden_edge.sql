-- Edge: the corners the rewrite is easiest to get wrong.

ANALYZE;

CREATE FUNCTION _hidden_plan(q text) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE plan text := ''; r record;
BEGIN
    FOR r IN EXECUTE 'EXPLAIN (COSTS OFF) ' || q LOOP
        plan := plan || r."QUERY PLAN" || E'\n';
    END LOOP;
    RETURN plan;
END $$;

DO $$
DECLARE plan text;
BEGIN
    plan := _hidden_plan('SELECT * FROM big_spenders WHERE customer_id = 42');
    IF plan LIKE '%SubPlan%' THEN
        RAISE EXCEPTION E'looking up one customer still runs a subquery:\n%', plan;
    END IF;

    plan := _hidden_plan('SELECT * FROM customer_latest_order WHERE customer_id = 42');
    IF plan LIKE '%SubPlan%' THEN
        RAISE EXCEPTION E'looking up one customer''s latest order still runs a subquery:\n%', plan;
    END IF;

    plan := _hidden_plan('SELECT * FROM march_orders');
    IF plan LIKE '%Seq Scan%' THEN
        RAISE EXCEPTION E'march_orders still reads every order:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- A customer who has never ordered is still listed, with nothing filled in.
    INSERT INTO customers (id, email, region) VALUES (90001, 'quiet@example.com', 'North');
    SELECT format('%s|%s|%s', email,
                  coalesce(latest_placed_at::text, '~'),
                  coalesce(latest_order_id::text, '~')) INTO got
    FROM customer_latest_order WHERE customer_id = 90001;
    IF got IS DISTINCT FROM 'quiet@example.com|~|~' THEN
        RAISE EXCEPTION 'a customer with no orders came out as %', coalesce(got, '<missing>');
    END IF;
END $$;

DO $$
DECLARE got integer;
BEGIN
    -- Two orders at the very same instant: the later id is the latest order.
    INSERT INTO orders (id, customer_id, placed_at, status) VALUES
        (900001, 1, TIMESTAMP '2024-12-31 00:00:00', 'shipped'),
        (900002, 1, TIMESTAMP '2024-12-31 00:00:00', 'shipped');
    SELECT latest_order_id INTO got FROM customer_latest_order WHERE customer_id = 1;
    IF got IS DISTINCT FROM 900002 THEN
        RAISE EXCEPTION 'with two orders at the same instant the latest was %, expected 900002',
            coalesce(got::text, '<null>');
    END IF;
END $$;

DO $$
DECLARE got text; total bigint;
BEGIN
    -- The window runs from the first of March up to but not into the eighth.
    INSERT INTO orders (id, customer_id, placed_at, status) VALUES
        (900010, 2, TIMESTAMP '2024-03-01 00:00:00', 'shipped'),
        (900011, 2, TIMESTAMP '2024-03-07 23:59:59', 'shipped'),
        (900012, 2, TIMESTAMP '2024-03-08 00:00:00', 'shipped'),
        (900013, 2, TIMESTAMP '2024-02-29 23:59:59', 'shipped');

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s', day, orders) AS line FROM march_orders ORDER BY day) t;
    IF got <> '2024-03-01|166
2024-03-02|165
2024-03-03|165
2024-03-04|165
2024-03-05|165
2024-03-06|165
2024-03-07|166' THEN
        RAISE EXCEPTION E'at the window edges march_orders reads\n%', got;
    END IF;

    SELECT sum(orders) INTO total FROM march_orders;
    IF total <> 1157 THEN
        RAISE EXCEPTION 'the window totals % orders, expected 1157', total;
    END IF;
END $$;

DO $$
DECLARE got text; n bigint;
BEGIN
    -- Cancelled orders are worth nothing, whatever they carry.
    INSERT INTO customers (id, email, region) VALUES
        (90002, 'voided@example.com', 'South'),
        (90003, 'whale@example.com',  'East');
    INSERT INTO orders (id, customer_id, placed_at, status) VALUES
        (900020, 90002, TIMESTAMP '2024-06-01 09:00:00', 'cancelled'),
        (900021, 90003, TIMESTAMP '2024-06-01 09:00:00', 'shipped');
    INSERT INTO order_items (id, order_id, sku, quantity, unit_price_cents) VALUES
        (9000001, 900020, 'SKU-X', 200, 1000),
        (9000002, 900021, 'SKU-X', 100, 1500);

    SELECT count(*) INTO n FROM big_spenders WHERE customer_id = 90002;
    IF n <> 0 THEN
        RAISE EXCEPTION 'a customer whose only order was cancelled counts as a big spender';
    END IF;

    SELECT format('%s|%s', email, total_cents) INTO got
    FROM big_spenders WHERE customer_id = 90003;
    IF got IS DISTINCT FROM 'whale@example.com|150000' THEN
        RAISE EXCEPTION 'the new big spender came out as %, expected whale@example.com|150000',
            coalesce(got, '<missing>');
    END IF;
END $$;
