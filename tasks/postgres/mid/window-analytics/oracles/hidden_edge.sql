-- Edge: ties, empty partitions, and the tie-break on equal effective dates.

DO $$
DECLARE got text;
BEGIN
    -- A third rep on the same total: all three share rank 1 and the next is 4.
    INSERT INTO reps (id, name, region) VALUES (7, 'Gil Amrani', 'North');
    INSERT INTO sales (id, rep_id, sold_on, amount_cents) VALUES (20, 7, DATE '2024-04-20', 50000);

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', region_rank, rep_id, total_cents, pct_of_region) AS line
          FROM rep_standings WHERE region = 'North' ORDER BY region_rank, rep_id) t;
    IF got <> '1|1|50000|29.41
1|2|50000|29.41
1|7|50000|29.41
4|3|20000|11.76' THEN
        RAISE EXCEPTION E'North standings after the three-way tie were\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- The running total picks up the new day and carries the earlier days forward.
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', sold_on, day_cents, running_cents) AS line
          FROM daily_running WHERE region = 'North' ORDER BY sold_on) t;
    IF got <> '2024-04-01|35000|35000
2024-04-03|40000|75000
2024-04-09|10000|85000
2024-04-12|35000|120000
2024-04-20|50000|170000' THEN
        RAISE EXCEPTION E'North running totals were\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- A correction filed later for the same day wins; a backdated one does not.
    INSERT INTO price_updates (id, sku, effective_on, price_cents, source) VALUES
        (20, 'A-1', DATE '2024-06-01', 1275, 'late-correction'),
        (21, 'B-2', DATE '2024-01-01', 4000, 'backfill');
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', sku, price_cents, effective_on, source) AS line
          FROM current_price ORDER BY sku) t;
    IF got <> 'A-1|1275|2024-06-01|late-correction
B-2|4500|2024-02-15|launch
C-3|900|2024-05-20|launch' THEN
        RAISE EXCEPTION E'current_price after the corrections was\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text; n bigint;
BEGIN
    -- A region whose reps have never sold anything still reports them, at zero.
    INSERT INTO reps (id, name, region) VALUES (8, 'Hana Loft', 'West'), (9, 'Ivo Renn', 'West');
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', region_rank, rep_id, total_cents,
                        coalesce(pct_of_region::text, '<null>')) AS line
          FROM rep_standings WHERE region = 'West' ORDER BY rep_id) t;
    IF got NOT LIKE '1|8|0|%' OR got NOT LIKE '%1|9|0|%' THEN
        RAISE EXCEPTION E'West standings were\n%', got;
    END IF;

    SELECT count(*) INTO n FROM daily_running WHERE region = 'West';
    IF n <> 0 THEN
        RAISE EXCEPTION 'a region with no sales produced % daily_running row(s)', n;
    END IF;
END $$;
