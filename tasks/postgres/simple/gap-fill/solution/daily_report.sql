-- Daily signup report, applied straight after schema.sql.

CREATE VIEW daily_signups AS
SELECT g.day_ts::date     AS day,
       src.code           AS source,
       count(s.id)::bigint AS signups
FROM generate_series(TIMESTAMP '2024-03-01', TIMESTAMP '2024-03-14', INTERVAL '1 day') AS g (day_ts)
CROSS JOIN sources src
LEFT JOIN signups s
       ON s.source_code = src.code
      AND s.created_at >= g.day_ts
      AND s.created_at <  g.day_ts + INTERVAL '1 day'
GROUP BY 1, 2;
