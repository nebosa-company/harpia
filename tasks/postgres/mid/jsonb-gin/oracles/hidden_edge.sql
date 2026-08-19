-- Edge: the tag lookup needs its own index, and both must be GIN.

ANALYZE events;

DO $$
DECLARE plan text := ''; r record;
BEGIN
    FOR r IN EXECUTE $q$EXPLAIN (COSTS OFF) SELECT id FROM events WHERE payload -> 'tags' ? 'paid'$q$ LOOP
        plan := plan || r."QUERY PLAN" || E'\n';
    END LOOP;
    IF plan LIKE '%Seq Scan%' THEN
        RAISE EXCEPTION E'the tag lookup still scans every event:\n%', plan;
    END IF;
    IF plan NOT LIKE '%Index%' THEN
        RAISE EXCEPTION E'the tag lookup does not use an index:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n
    FROM pg_index i
    JOIN pg_class ic ON ic.oid = i.indexrelid
    JOIN pg_class tc ON tc.oid = i.indrelid
    JOIN pg_am  am ON am.oid = ic.relam
    WHERE tc.relname = 'events' AND am.amname = 'gin';
    IF n < 2 THEN
        RAISE EXCEPTION 'events carries % GIN index(es); containment and tag lookups need one each', n;
    END IF;
END $$;

DO $$
DECLARE got text; n bigint;
BEGIN
    -- New events are picked up by both the rollup and the tag lookup.
    INSERT INTO events (id, occurred_at, payload) VALUES
        (900001, TIMESTAMP '2024-06-01 00:00:00',
         '{"type": "checkout", "tenant": "tenant-9", "cents": 2500, "tags": ["paid", "gift"]}'::jsonb),
        (900002, TIMESTAMP '2024-06-01 00:00:01',
         '{"type": "view", "tenant": "tenant-9", "cents": 1, "tags": ["gift"]}'::jsonb);

    SELECT format('%s|%s|%s', tenant, checkouts, cents) INTO got
    FROM checkout_totals WHERE tenant = 'tenant-9';
    IF got IS DISTINCT FROM 'tenant-9|1|2500' THEN
        RAISE EXCEPTION 'the new tenant rolled up as %, expected tenant-9|1|2500',
            coalesce(got, '<missing>');
    END IF;

    SELECT count(*) INTO n FROM events_with_tag('gift');
    IF n <> 2 THEN RAISE EXCEPTION 'events_with_tag(gift) returned % rows, expected 2', n; END IF;

    SELECT count(*) INTO n FROM events_with_tag('paid');
    IF n <> 852 THEN RAISE EXCEPTION 'events_with_tag(paid) returned % rows, expected 852', n; END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Containment is on the whole payload, not just the type key.
    SELECT count(*) INTO n FROM events
    WHERE payload @> '{"type": "checkout", "tenant": "tenant-9"}'::jsonb;
    IF n <> 1 THEN
        RAISE EXCEPTION 'a two-key containment query matched % rows, expected 1', n;
    END IF;
END $$;
