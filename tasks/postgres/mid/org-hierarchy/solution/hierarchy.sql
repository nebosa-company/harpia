-- Directory queries. Define org_chart, reports_of and team_totals here.
-- This file is applied immediately after schema.sql.

CREATE VIEW org_chart AS
WITH RECURSIVE walk AS (
    SELECT e.id, e.name, e.manager_id, 0 AS depth, '/' || e.id AS path
    FROM employees e
    WHERE e.manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id, w.depth + 1, w.path || '/' || e.id
    FROM employees e
    JOIN walk w ON e.manager_id = w.id
)
SELECT id, name, manager_id, depth, path FROM walk;

CREATE FUNCTION reports_of(p_manager_id integer)
RETURNS TABLE (id integer, name text, depth integer)
LANGUAGE sql STABLE AS $$
    WITH RECURSIVE walk AS (
        SELECT e.id, e.name, 1 AS depth
        FROM employees e
        WHERE e.manager_id = p_manager_id
        UNION ALL
        SELECT e.id, e.name, w.depth + 1
        FROM employees e
        JOIN walk w ON e.manager_id = w.id
    )
    SELECT walk.id, walk.name, walk.depth FROM walk;
$$;

CREATE VIEW team_totals AS
SELECT m.id                                             AS manager_id,
       m.name                                           AS manager_name,
       (SELECT count(*) FROM employees d WHERE d.manager_id = m.id)::bigint
                                                        AS direct_reports,
       (SELECT count(*) FROM reports_of(m.id))::bigint  AS all_reports,
       (m.salary_cents
        + coalesce((SELECT sum(e.salary_cents)
                    FROM reports_of(m.id) r
                    JOIN employees e ON e.id = r.id), 0))::bigint
                                                        AS org_salary_cents
FROM employees m;
