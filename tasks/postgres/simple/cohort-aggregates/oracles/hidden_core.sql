-- Core: the reported cohorts, exactly and in order.

DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(c.col, ', ' ORDER BY c.col) INTO missing
    FROM (VALUES ('cohort_month'), ('accounts'), ('paying_accounts'),
                 ('total_cents'), ('avg_cents')) AS c (col)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'cohort_summary'
          AND column_name = c.col);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'cohort_summary is missing column(s): %', missing;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s', cohort_month, accounts, paying_accounts,
                        total_cents, avg_cents) AS line
          FROM cohort_summary
          ORDER BY cohort_month) t;

    want := '2023-01-01|4|2|169500|42375.00
2023-03-01|4|2|119600|29900.00
2023-04-01|3|0|0|0.00';

    IF got <> want THEN
        RAISE EXCEPTION E'cohort_summary does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;
