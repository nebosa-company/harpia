-- Daily signup report, applied straight after schema.sql.

CREATE VIEW daily_signups AS
SELECT s.created_at::date AS day,
       s.source_code      AS source,
       count(*)::bigint   AS signups
FROM signups s
WHERE s.created_at >= TIMESTAMP '2024-03-01 00:00:00'
  AND s.created_at <  TIMESTAMP '2024-03-15 00:00:00'
GROUP BY 1, 2;
