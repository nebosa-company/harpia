-- Core: containment must be served from an index, and the rollup must be right.

ANALYZE events;

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
    plan := _hidden_plan($q$SELECT id FROM events WHERE payload @> '{"type": "checkout"}'::jsonb$q$);
    IF plan LIKE '%Seq Scan%' THEN
        RAISE EXCEPTION E'the containment query still scans every event:\n%', plan;
    END IF;
    IF plan NOT LIKE '%Index%' THEN
        RAISE EXCEPTION E'the containment query does not use an index:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', tenant, checkouts, cents) AS line
          FROM checkout_totals ORDER BY tenant) t;
    want := 'tenant-0|212|4244664
tenant-1|213|4274697
tenant-2|213|4264686
tenant-3|213|4254675';
    IF got <> want THEN
        RAISE EXCEPTION E'checkout_totals does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

DO $$
DECLARE n bigint; got text;
BEGIN
    SELECT count(*) INTO n FROM events_with_tag('paid');
    IF n <> 851 THEN RAISE EXCEPTION 'events_with_tag(paid) returned % rows, expected 851', n; END IF;

    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT id::text AS line FROM events_with_tag('paid') ORDER BY id LIMIT 5) t;
    IF got <> '47,94,141,188,235' THEN
        RAISE EXCEPTION 'events_with_tag(paid) started with %', got;
    END IF;

    SELECT count(*) INTO n FROM events_with_tag('cart');
    IF n <> 2302 THEN RAISE EXCEPTION 'events_with_tag(cart) returned % rows, expected 2302', n; END IF;

    SELECT count(*) INTO n FROM events_with_tag('nope');
    IF n <> 0 THEN RAISE EXCEPTION 'events_with_tag(nope) returned % rows, expected 0', n; END IF;
END $$;
