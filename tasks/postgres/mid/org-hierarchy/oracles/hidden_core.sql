-- Core: the whole directory walked out, and the per-manager rollups.

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s', id, name, coalesce(manager_id::text, '<null>'),
                        depth, path) AS line
          FROM org_chart ORDER BY path) t;
    want := '1|Rosalind Vega|<null>|0|/1
2|Idris Bello|1|1|/1/2
4|Tomasz Reik|2|2|/1/2/4
6|Paulo Serra|4|3|/1/2/4/6
8|Alex Turchin|6|4|/1/2/4/6/8
7|Kiri Manaia|4|3|/1/2/4/7
5|Nour Haddad|2|2|/1/2/5
9|Devi Raman|5|3|/1/2/5/9
3|Mira Kohl|1|1|/1/3
10|Sam Oyelaran|3|2|/1/3/10
11|Wren Fisk|10|3|/1/3/10/11
12|Cato Iversen|<null>|0|/12
13|Lena Brandt|12|1|/12/13';
    IF got <> want THEN
        RAISE EXCEPTION E'org_chart does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s', manager_id, manager_name, direct_reports,
                        all_reports, org_salary_cents) AS line
          FROM team_totals ORDER BY manager_id) t;
    want := '1|Rosalind Vega|2|10|14540000
2|Idris Bello|2|6|8710000
3|Mira Kohl|1|2|3430000
4|Tomasz Reik|2|3|4550000
5|Nour Haddad|1|1|2360000
6|Paulo Serra|1|1|2100000
7|Kiri Manaia|0|0|1050000
8|Alex Turchin|0|0|900000
9|Devi Raman|0|0|980000
10|Sam Oyelaran|1|1|1680000
11|Wren Fisk|0|0|720000
12|Cato Iversen|1|1|2380000
13|Lena Brandt|0|0|880000';
    IF got <> want THEN
        RAISE EXCEPTION E'team_totals does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', id, name, depth) AS line
          FROM reports_of(2) ORDER BY depth, id) t;
    IF got <> '4|Tomasz Reik|1
5|Nour Haddad|1
6|Paulo Serra|2
7|Kiri Manaia|2
9|Devi Raman|2
8|Alex Turchin|3' THEN
        RAISE EXCEPTION E'reports_of(2) returned\n%', got;
    END IF;
END $$;
