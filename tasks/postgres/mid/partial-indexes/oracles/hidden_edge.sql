-- Edge: the indexes must be the narrow ones asked for, not blanket coverage.

ANALYZE jobs;

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indrelid
    WHERE c.relname = 'jobs';
    IF n > 3 THEN
        RAISE EXCEPTION 'jobs carries % indexes; the primary key plus the two new ones is 3', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indrelid
    WHERE c.relname = 'jobs' AND i.indpred IS NOT NULL;
    IF n < 1 THEN
        RAISE EXCEPTION 'no partial index on jobs: the claim index still covers the whole history';
    END IF;

    SELECT count(*) INTO n
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indrelid
    WHERE c.relname = 'jobs' AND i.indexprs IS NOT NULL;
    IF n < 1 THEN
        RAISE EXCEPTION 'no expression index on jobs: the case-folded lookup has nothing to read';
    END IF;
END $$;

DO $$
DECLARE entries bigint; total bigint;
BEGIN
    -- The partial index must cover only the pending slice.
    SELECT count(*) INTO entries FROM jobs WHERE state = 'pending';
    SELECT count(*) INTO total FROM jobs;
    IF entries * 20 > total THEN
        RAISE EXCEPTION 'the pending slice is not small (% of % rows); the fixture is wrong',
            entries, total;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indrelid
        WHERE c.relname = 'jobs'
          AND i.indpred IS NOT NULL
          AND pg_get_expr(i.indpred, i.indrelid) LIKE '%pending%')
    THEN
        RAISE EXCEPTION 'the partial index on jobs is not restricted to the pending rows';
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Newly queued work is found straight away, and finished work drops out.
    INSERT INTO jobs (id, queue, state, assignee, run_after, payload)
        VALUES (900001, 'queue-3', 'pending', 'Zoe Ng',
                TIMESTAMP '2024-01-01 00:01:00', 'fresh');

    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT id::text AS line FROM jobs
          WHERE state = 'pending' AND queue = 'queue-3'
            AND run_after <= TIMESTAMP '2024-02-01 00:00:00'
          ORDER BY run_after LIMIT 3) t;
    IF got <> '900001,398,1393' THEN
        RAISE EXCEPTION 'after queueing new work the claim query returned %', got;
    END IF;

    UPDATE jobs SET state = 'done' WHERE id = 900001;
    SELECT count(*)::text INTO got FROM jobs
    WHERE state = 'pending' AND queue = 'queue-3' AND id = 900001;
    IF got <> '0' THEN
        RAISE EXCEPTION 'a finished job is still claimable';
    END IF;
END $$;

DO $$
DECLARE plan text := ''; r record;
BEGIN
    -- Case folding really is applied: the raw stored spelling matches too.
    FOR r IN EXECUTE $q$EXPLAIN (COSTS OFF) SELECT id FROM jobs WHERE lower(assignee) = 'ada lovelace'$q$ LOOP
        plan := plan || r."QUERY PLAN" || E'\n';
    END LOOP;
    IF plan LIKE '%Seq Scan%' THEN
        RAISE EXCEPTION E'the second assignee lookup still scans the table:\n%', plan;
    END IF;
END $$;
