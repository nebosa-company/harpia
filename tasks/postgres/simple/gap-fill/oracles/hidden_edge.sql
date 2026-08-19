-- Edge: grid completeness, new sources, and the window boundaries.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM daily_signups;
    IF n <> 56 THEN
        RAISE EXCEPTION 'expected 56 rows (14 days x 4 sources), found %', n;
    END IF;
    SELECT count(*) INTO n FROM daily_signups
    WHERE day IS NULL OR source IS NULL OR signups IS NULL;
    IF n <> 0 THEN
        RAISE EXCEPTION 'daily_signups has % row(s) with a NULL column', n;
    END IF;
END $$;

DO $$
DECLARE got bigint;
BEGIN
    INSERT INTO signups (id, source_code, created_at)
        VALUES (100, 'kiosk', TIMESTAMP '2024-03-09 14:00:00');
    SELECT signups INTO got FROM daily_signups
    WHERE day = DATE '2024-03-09' AND source = 'kiosk';
    IF got IS DISTINCT FROM 1::bigint THEN
        RAISE EXCEPTION '2024-03-09 kiosk was %, expected 1', coalesce(got::text, '<missing>');
    END IF;
    SELECT signups INTO got FROM daily_signups
    WHERE day = DATE '2024-03-09' AND source = 'web';
    IF got IS DISTINCT FROM 0::bigint THEN
        RAISE EXCEPTION '2024-03-09 web was %, expected 0', coalesce(got::text, '<missing>');
    END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    INSERT INTO sources (code, label) VALUES ('phone', 'Phone order');
    SELECT count(*) INTO n FROM daily_signups WHERE source = 'phone';
    IF n <> 14 THEN
        RAISE EXCEPTION 'a newly registered source got % day rows, expected 14', n;
    END IF;
    SELECT count(*) INTO n FROM daily_signups WHERE source = 'phone' AND signups <> 0;
    IF n <> 0 THEN
        RAISE EXCEPTION 'a source with no signups reported % non-zero day(s)', n;
    END IF;
END $$;

DO $$
DECLARE total bigint;
BEGIN
    INSERT INTO signups (id, source_code, created_at) VALUES
        (101, 'web', TIMESTAMP '2024-02-29 12:00:00'),
        (102, 'web', TIMESTAMP '2024-03-15 00:00:00');
    SELECT sum(signups) INTO total FROM daily_signups WHERE source = 'web';
    IF total <> 9 THEN
        RAISE EXCEPTION 'web signups over the window totalled %, expected 9 (rows outside 2024-03-01..2024-03-14 must not count)', total;
    END IF;
END $$;
