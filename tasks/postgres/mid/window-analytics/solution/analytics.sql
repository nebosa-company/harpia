-- Analytics layer. Define daily_running, rep_standings and current_price here.
-- This file is applied immediately after schema.sql.

CREATE VIEW daily_running AS
SELECT d.region,
       d.sold_on,
       d.day_cents,
       sum(d.day_cents) OVER (PARTITION BY d.region
                              ORDER BY d.sold_on
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::bigint
           AS running_cents
FROM (
    SELECT r.region, s.sold_on, sum(s.amount_cents)::bigint AS day_cents
    FROM sales s
    JOIN reps r ON r.id = s.rep_id
    GROUP BY r.region, s.sold_on
) d;

CREATE VIEW rep_standings AS
SELECT t.region,
       t.rep_id,
       t.rep_name,
       t.total_cents,
       rank() OVER (PARTITION BY t.region ORDER BY t.total_cents DESC)::bigint AS region_rank,
       round(t.total_cents * 100.0
             / nullif(sum(t.total_cents) OVER (PARTITION BY t.region), 0), 2) AS pct_of_region
FROM (
    SELECT r.region,
           r.id                                  AS rep_id,
           r.name                                AS rep_name,
           coalesce(sum(s.amount_cents), 0)::bigint AS total_cents
    FROM reps r
    LEFT JOIN sales s ON s.rep_id = r.id
    GROUP BY r.region, r.id, r.name
) t;

CREATE VIEW current_price AS
SELECT DISTINCT ON (p.sku)
       p.sku, p.price_cents, p.effective_on, p.source
FROM price_updates p
ORDER BY p.sku, p.effective_on DESC, p.id DESC;
