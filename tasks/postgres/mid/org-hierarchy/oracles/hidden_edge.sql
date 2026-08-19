-- Edge: leaves, unknown ids, reorganisations, and freshly planted trees.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM reports_of(8);
    IF n <> 0 THEN RAISE EXCEPTION 'a leaf reported % descendant(s)', n; END IF;
    SELECT count(*) INTO n FROM reports_of(9999);
    IF n <> 0 THEN RAISE EXCEPTION 'an unknown manager id reported % descendant(s)', n; END IF;
    SELECT count(*) INTO n FROM reports_of(1);
    IF n <> 10 THEN RAISE EXCEPTION 'the chief executive has % descendants, expected 10', n; END IF;
    SELECT depth INTO n FROM reports_of(1) WHERE id = 11;
    IF n IS DISTINCT FROM 3 THEN
        RAISE EXCEPTION 'employee 11 sits at depth % below employee 1, expected 3',
            coalesce(n::text, '<missing>');
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- A reorganisation moves a whole branch to the other tree.
    UPDATE employees SET manager_id = 12 WHERE id = 10;

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', id, depth, path) AS line
          FROM org_chart WHERE id IN (10, 11) ORDER BY id) t;
    IF got <> '10|1|/12/10
11|2|/12/10/11' THEN
        RAISE EXCEPTION E'after the move the branch looked like\n%', got;
    END IF;

    SELECT format('%s|%s|%s', direct_reports, all_reports, org_salary_cents) INTO got
    FROM team_totals WHERE manager_id = 3;
    IF got IS DISTINCT FROM '0|0|1750000' THEN
        RAISE EXCEPTION 'the emptied manager reported %, expected 0|0|1750000',
            coalesce(got, '<missing>');
    END IF;

    SELECT format('%s|%s|%s', direct_reports, all_reports, org_salary_cents) INTO got
    FROM team_totals WHERE manager_id = 12;
    IF got IS DISTINCT FROM '2|3|4060000' THEN
        RAISE EXCEPTION 'the receiving manager reported %, expected 2|3|4060000',
            coalesce(got, '<missing>');
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- A brand new tree of one.
    INSERT INTO employees (id, name, manager_id, title, salary_cents)
        VALUES (14, 'Odile Frei', NULL, 'Advisor', 500000);
    SELECT format('%s|%s', depth, path) INTO got FROM org_chart WHERE id = 14;
    IF got IS DISTINCT FROM '0|/14' THEN
        RAISE EXCEPTION 'a new root came out as %, expected 0|/14', coalesce(got, '<missing>');
    END IF;
    SELECT format('%s|%s|%s', direct_reports, all_reports, org_salary_cents) INTO got
    FROM team_totals WHERE manager_id = 14;
    IF got IS DISTINCT FROM '0|0|500000' THEN
        RAISE EXCEPTION 'the new root rolled up as %, expected 0|0|500000',
            coalesce(got, '<missing>');
    END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Everybody in the directory is reachable from some root.
    SELECT count(*) INTO n FROM employees;
    IF (SELECT count(*) FROM org_chart) <> n THEN
        RAISE EXCEPTION 'org_chart lists % of % employees',
            (SELECT count(*) FROM org_chart), n;
    END IF;
END $$;
