-- The numbers the reporting team already relies on. They must not move.
-- Run this file to see whether a rewrite still answers the same questions.

ANALYZE;

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
        RAISE EXCEPTION 'customer_latest_order no longer returns the same rows';
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

DO $$
DECLARE n bigint; total bigint;
BEGIN
    SELECT count(*), coalesce(sum(total_cents), 0) INTO n, total FROM big_spenders;
    IF n <> 954 THEN RAISE EXCEPTION 'big_spenders returned % rows, expected 954', n; END IF;
    IF total <> 96365778 THEN
        RAISE EXCEPTION 'big_spenders totals %, expected 96365778', total;
    END IF;
END $$;
