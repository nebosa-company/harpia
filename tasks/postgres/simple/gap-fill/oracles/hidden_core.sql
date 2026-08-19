-- Core: one row per day per source across the whole window, exactly.

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', day, source, signups) AS line
          FROM daily_signups
          ORDER BY day, source) t;

    want := '2024-03-01|kiosk|0
2024-03-01|mobile|1
2024-03-01|partner|0
2024-03-01|web|2
2024-03-02|kiosk|0
2024-03-02|mobile|0
2024-03-02|partner|0
2024-03-02|web|1
2024-03-03|kiosk|0
2024-03-03|mobile|0
2024-03-03|partner|1
2024-03-03|web|0
2024-03-04|kiosk|0
2024-03-04|mobile|0
2024-03-04|partner|0
2024-03-04|web|0
2024-03-05|kiosk|0
2024-03-05|mobile|3
2024-03-05|partner|0
2024-03-05|web|0
2024-03-06|kiosk|0
2024-03-06|mobile|0
2024-03-06|partner|0
2024-03-06|web|1
2024-03-07|kiosk|0
2024-03-07|mobile|0
2024-03-07|partner|0
2024-03-07|web|0
2024-03-08|kiosk|0
2024-03-08|mobile|0
2024-03-08|partner|1
2024-03-08|web|1
2024-03-09|kiosk|0
2024-03-09|mobile|0
2024-03-09|partner|0
2024-03-09|web|0
2024-03-10|kiosk|0
2024-03-10|mobile|0
2024-03-10|partner|0
2024-03-10|web|0
2024-03-11|kiosk|0
2024-03-11|mobile|0
2024-03-11|partner|0
2024-03-11|web|3
2024-03-12|kiosk|0
2024-03-12|mobile|1
2024-03-12|partner|0
2024-03-12|web|0
2024-03-13|kiosk|0
2024-03-13|mobile|0
2024-03-13|partner|0
2024-03-13|web|0
2024-03-14|kiosk|0
2024-03-14|mobile|0
2024-03-14|partner|1
2024-03-14|web|1';

    IF got <> want THEN
        RAISE EXCEPTION E'daily_signups does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;
