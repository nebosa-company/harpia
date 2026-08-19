-- Core: both hot queries must be served from an index, not a table scan.

ANALYZE jobs;

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
    plan := _hidden_plan($q$
        SELECT id, payload FROM jobs
        WHERE state = 'pending' AND queue = 'queue-3'
          AND run_after <= TIMESTAMP '2024-02-01 00:00:00'
        ORDER BY run_after
        LIMIT 20 $q$);
    IF plan LIKE '%Seq Scan%' THEN
        RAISE EXCEPTION E'the claim query still scans the whole table:\n%', plan;
    END IF;
    IF plan NOT LIKE '%Index%' THEN
        RAISE EXCEPTION E'the claim query does not use an index:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE plan text;
BEGIN
    plan := _hidden_plan($q$SELECT id FROM jobs WHERE lower(assignee) = 'bowen okafor'$q$);
    IF plan LIKE '%Seq Scan%' THEN
        RAISE EXCEPTION E'the case-folded assignee lookup still scans the whole table:\n%', plan;
    END IF;
    IF plan NOT LIKE '%Index%' THEN
        RAISE EXCEPTION E'the case-folded assignee lookup does not use an index:\n%', plan;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- The indexes must not have changed what the queries return.
    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT id::text AS line FROM jobs
          WHERE state = 'pending' AND queue = 'queue-3'
            AND run_after <= TIMESTAMP '2024-02-01 00:00:00'
          ORDER BY run_after LIMIT 5) t;
    IF got <> '398,1393,2388,3383,4378' THEN
        RAISE EXCEPTION 'the claim query returned %', got;
    END IF;

    SELECT count(*)::text INTO got FROM jobs WHERE lower(assignee) = 'bowen okafor';
    IF got <> '20000' THEN
        RAISE EXCEPTION 'the assignee lookup matched % rows, expected 20000', got;
    END IF;
END $$;
