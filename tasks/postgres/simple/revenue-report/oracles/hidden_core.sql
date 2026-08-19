-- Core: the shape of monthly_revenue and its published rows, exactly.

DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(c.col, ', ' ORDER BY c.col) INTO missing
    FROM (VALUES ('month'), ('region'), ('order_count'), ('gross_cents'), ('net_cents')) AS c (col)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'monthly_revenue'
          AND column_name = c.col);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'monthly_revenue is missing column(s): %', missing;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s', month, region, order_count, gross_cents, net_cents) AS line
          FROM monthly_revenue
          ORDER BY month, region) t;

    want := '2024-01-01|North|2|27500|26000
2024-01-01|South|1|12000|12000
2024-02-01|East|1|24000|22000
2024-02-01|North|1|17000|15800
2024-02-01|South|1|10000|9750
2024-03-01|South|1|15000|15000';

    IF got <> want THEN
        RAISE EXCEPTION E'monthly_revenue does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;
