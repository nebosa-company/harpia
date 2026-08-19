-- Core: the three analytics views, exactly and in order.

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', region, sold_on, day_cents, running_cents) AS line
          FROM daily_running ORDER BY region, sold_on) t;
    want := 'East|2024-04-05|12000|12000
North|2024-04-01|35000|35000
North|2024-04-03|40000|75000
North|2024-04-09|10000|85000
North|2024-04-12|35000|120000
South|2024-04-02|20000|20000
South|2024-04-18|10000|30000';
    IF got <> want THEN
        RAISE EXCEPTION E'daily_running does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s|%s', region, region_rank, rep_id, rep_name,
                        total_cents, pct_of_region) AS line
          FROM rep_standings ORDER BY region, region_rank, rep_id) t;
    want := 'East|1|6|Fay Adeyemi|12000|100.00
East|2|5|Eli Barron|0|0.00
North|1|1|Ana Duarte|50000|41.67
North|1|2|Ben Ostrom|50000|41.67
North|3|3|Cleo Nakata|20000|16.67
South|1|4|Dov Hersch|30000|100.00';
    IF got <> want THEN
        RAISE EXCEPTION E'rep_standings does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', sku, price_cents, effective_on, source) AS line
          FROM current_price ORDER BY sku) t;
    want := 'A-1|1250|2024-06-01|correction
B-2|4500|2024-02-15|launch
C-3|900|2024-05-20|launch';
    IF got <> want THEN
        RAISE EXCEPTION E'current_price does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;
