-- Checks the reporting team already runs against orders_wide. They must keep
-- passing after the split; run this file to see where you stand.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM orders_wide;
    IF n <> 10 THEN RAISE EXCEPTION 'orders_wide has % rows, expected 10', n; END IF;

    SELECT count(DISTINCT order_ref) INTO n FROM orders_wide;
    IF n <> 6 THEN RAISE EXCEPTION 'orders_wide covers % orders, expected 6', n; END IF;

    SELECT count(DISTINCT customer_email) INTO n FROM orders_wide;
    IF n <> 3 THEN RAISE EXCEPTION 'orders_wide covers % customers, expected 3', n; END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', line_no, sku, quantity, unit_price_cents) AS line
          FROM orders_wide WHERE order_ref = 'ORD-1003' ORDER BY line_no) t;
    IF got <> '1|MAT-01|3|7900
2|LAMP-01|1|4900
3|RISER-01|2|2900' THEN
        RAISE EXCEPTION E'ORD-1003 reads back as\n%', got;
    END IF;
END $$;

DO $$
DECLARE cents bigint;
BEGIN
    SELECT sum(quantity * unit_price_cents) INTO cents
    FROM orders_wide WHERE status <> 'cancelled';
    IF cents <> 249600 THEN
        RAISE EXCEPTION 'non-cancelled revenue is %, expected 249600', cents;
    END IF;
END $$;
