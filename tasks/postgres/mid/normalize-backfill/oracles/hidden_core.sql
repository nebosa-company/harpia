-- Core: the split happened, and orders_wide still reads back byte for byte.

DO $$
DECLARE kind "char";
BEGIN
    SELECT relkind INTO kind FROM pg_class WHERE relname = 'orders_wide' AND relnamespace = 'public'::regnamespace;
    IF kind IS NULL THEN RAISE EXCEPTION 'orders_wide is gone; existing readers would break'; END IF;
    IF kind <> 'v' THEN
        RAISE EXCEPTION 'orders_wide is still a % rather than a view over the new tables', kind;
    END IF;
END $$;

DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(t.name, ', ' ORDER BY t.name) INTO missing
    FROM (VALUES ('customers'), ('orders'), ('order_lines')) AS t (name)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = t.name AND table_type = 'BASE TABLE');
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'these tables were not created: %', missing;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s|%s|%s|%s|%s',
                        order_ref, customer_email, customer_name, placed_on, status,
                        line_no, sku, quantity, unit_price_cents) AS line
          FROM orders_wide ORDER BY order_ref, line_no) t;

    want := 'ORD-1001|rosa@example.com|Rosa Klein|2024-02-03|shipped|1|DESK-01|1|89900
ORD-1001|rosa@example.com|Rosa Klein|2024-02-03|shipped|2|LAMP-01|2|4900
ORD-1002|imre@example.org|Imre Bako|2024-02-05|shipped|1|CHAIR-01|1|34900
ORD-1003|rosa@example.com|Rosa Klein|2024-02-11|placed|1|MAT-01|3|7900
ORD-1003|rosa@example.com|Rosa Klein|2024-02-11|placed|2|LAMP-01|1|4900
ORD-1003|rosa@example.com|Rosa Klein|2024-02-11|placed|3|RISER-01|2|2900
ORD-1004|nadia@example.net|Nadia Farouk|2024-02-14|cancelled|1|DESK-01|1|89900
ORD-1005|imre@example.org|Imre Bako|2024-02-20|shipped|1|RISER-01|1|2900
ORD-1005|imre@example.org|Imre Bako|2024-02-20|shipped|2|MAT-01|1|7900
ORD-1006|rosa@example.com|Rosa Klein|2024-03-01|placed|1|CHAIR-01|2|34900';

    IF got <> want THEN
        RAISE EXCEPTION E'orders_wide changed\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM customers;
    IF n <> 3 THEN RAISE EXCEPTION 'customers holds % rows, expected 3 (one per address)', n; END IF;
    SELECT count(*) INTO n FROM orders;
    IF n <> 6 THEN RAISE EXCEPTION 'orders holds % rows, expected 6', n; END IF;
    SELECT count(*) INTO n FROM order_lines;
    IF n <> 10 THEN RAISE EXCEPTION 'order_lines holds % rows, expected 10', n; END IF;

    SELECT count(*) INTO n FROM orders o
    JOIN customers c ON c.id = o.customer_id
    WHERE c.email = 'rosa@example.com';
    IF n <> 3 THEN
        RAISE EXCEPTION 'the repeat customer owns % orders, expected 3', n;
    END IF;
END $$;
