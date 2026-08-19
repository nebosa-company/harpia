-- Cohort reporting. Define the cohort_summary view here.
-- This file is applied immediately after schema.sql.

CREATE VIEW cohort_summary AS
SELECT date_trunc('month', a.signed_up_on)::date AS cohort_month,
       count(DISTINCT a.id)::bigint              AS accounts,
       count(DISTINCT p.account_id)::bigint      AS paying_accounts,
       coalesce(sum(p.amount_cents), 0)::bigint  AS total_cents,
       round(coalesce(sum(p.amount_cents), 0)::numeric
             / count(DISTINCT a.id), 2)          AS avg_cents
FROM accounts a
LEFT JOIN payments p ON p.account_id = a.id
GROUP BY 1
HAVING count(DISTINCT a.id) >= 3;
