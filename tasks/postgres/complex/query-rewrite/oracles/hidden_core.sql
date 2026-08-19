-- Core: the same answers, reached without a per-row subquery or a table scan.

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
    plan := _hidden_plan('SELECT * FROM customer_latest_order');
    IF plan LIKE '%SubPlan%' THEN
        RAISE EXCEPTION E'customer_latest_order still runs a subquery per customer:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE plan text;
BEGIN
    plan := _hidden_plan('SELECT * FROM big_spenders');
    IF plan LIKE '%SubPlan%' THEN
        RAISE EXCEPTION E'big_spenders still runs a subquery per customer:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE plan text;
BEGIN
    plan := _hidden_plan('SELECT * FROM march_orders');
    IF plan LIKE '%Seq Scan%' THEN
        RAISE EXCEPTION E'march_orders still reads every order:\n%', plan;
    END IF;
    IF plan NOT LIKE '%Index%' THEN
        RAISE EXCEPTION E'march_orders is not answered from an index:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE n bigint; sig text;
BEGIN
    SELECT count(*), md5(string_agg(t.line, E'\n' ORDER BY t.line)) INTO n, sig
    FROM (SELECT format('%s|%s|%s|%s', customer_id, email,
                        coalesce(latest_placed_at::text, '~'),
                        coalesce(latest_order_id::text, '~')) AS line
          FROM customer_latest_order) t;
    IF n <> 5000 THEN
        RAISE EXCEPTION 'customer_latest_order returned % rows, expected 5000', n;
    END IF;
    IF sig <> '67f9cbb9843a7fe4d3ecc831b40399f2' THEN
        RAISE EXCEPTION 'customer_latest_order no longer returns the same rows (digest %)', sig;
    END IF;
END $$;

DO $$
DECLARE n bigint; total bigint; sig text;
BEGIN
    SELECT count(*), coalesce(sum(t.total_cents), 0),
           md5(string_agg(t.line, E'\n' ORDER BY t.line))
      INTO n, total, sig
    FROM (SELECT total_cents,
                 format('%s|%s|%s', customer_id, email, total_cents) AS line
          FROM big_spenders) t;
    IF n <> 954 THEN RAISE EXCEPTION 'big_spenders returned % rows, expected 954', n; END IF;
    IF total <> 96365778 THEN
        RAISE EXCEPTION 'big_spenders totals %, expected 96365778', total;
    END IF;
    IF sig <> 'dd14ede95d8da058df8191bc3d62733c' THEN
        RAISE EXCEPTION 'big_spenders no longer returns the same rows (digest %)', sig;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s', day, orders) AS line FROM march_orders ORDER BY day) t;
    IF got <> '2024-03-01|165
2024-03-02|165
2024-03-03|165
2024-03-04|165
2024-03-05|165
2024-03-06|165
2024-03-07|165' THEN
        RAISE EXCEPTION E'march_orders now reads\n%', got;
    END IF;
END $$;
