-- Core: the numbers are right, and the rollup only moves when it is refreshed.

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', region, orders, cents) AS line
          FROM sales_rollup ORDER BY region) t;
    want := 'East|1|6000
North|2|37500
South|2|22500';
    IF got <> want THEN
        RAISE EXCEPTION E'sales_rollup does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

INSERT INTO orders (id, region, status, placed_on) VALUES (9, 'North', 'shipped', DATE '2024-05-25');
INSERT INTO order_items (id, order_id, sku, amount_cents) VALUES
    (13, 9, 'A-1', 1000),
    (14, 9, 'B-2', 2000);

DO $$
DECLARE got text;
BEGIN
    SELECT format('%s|%s', orders, cents) INTO got FROM sales_rollup WHERE region = 'North';
    IF got IS DISTINCT FROM '2|37500' THEN
        RAISE EXCEPTION 'the rollup moved before it was refreshed: North reads %',
            coalesce(got, '<missing>');
    END IF;
END $$;

SELECT refresh_sales_rollup();

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', region, orders, cents) AS line
          FROM sales_rollup ORDER BY region) t;
    want := 'East|1|6000
North|3|40500
South|2|22500';
    IF got <> want THEN
        RAISE EXCEPTION E'after the refresh sales_rollup was\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

INSERT INTO orders (id, region, status, placed_on) VALUES (10, 'West', 'cancelled', DATE '2024-05-26');
INSERT INTO order_items (id, order_id, sku, amount_cents) VALUES (15, 10, 'A-1', 500000);

SELECT refresh_sales_rollup();

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM sales_rollup WHERE region = 'West';
    IF n <> 0 THEN
        RAISE EXCEPTION 'a region whose only order was cancelled appeared in the rollup';
    END IF;
END $$;
