-- Core: the schema holds the opening data, and reporting reads back correctly.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM branches;
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 branches, found %', n; END IF;
    SELECT count(*) INTO n FROM members;
    IF n <> 5 THEN RAISE EXCEPTION 'expected 5 members, found %', n; END IF;
    SELECT count(*) INTO n FROM titles;
    IF n <> 4 THEN RAISE EXCEPTION 'expected 4 titles, found %', n; END IF;
    SELECT count(*) INTO n FROM copies;
    IF n <> 10 THEN RAISE EXCEPTION 'expected 10 copies, found %', n; END IF;
    SELECT count(*) INTO n FROM loans;
    IF n <> 7 THEN RAISE EXCEPTION 'expected 7 loans, found %', n; END IF;
    SELECT count(*) INTO n FROM holds;
    IF n <> 4 THEN RAISE EXCEPTION 'expected 4 holds, found %', n; END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s', branch_code, isbn, total_copies, on_loan, available) AS line
          FROM branch_stock ORDER BY branch_code, isbn) t;
    want := 'CEN|9780000000001|2|1|1
CEN|9780000000002|1|1|0
CEN|9780000000003|1|0|1
RIV|9780000000001|1|1|0
RIV|9780000000002|1|0|1
RIV|9780000000004|2|1|1';
    IF got <> want THEN
        RAISE EXCEPTION E'branch_stock does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n' ORDER BY t.ord), '<no rows>') INTO got
    FROM (SELECT o.ord,
                 format('%s|%s|%s|%s|%s|%s', o.loan_id, o.membership_no, o.barcode,
                        o.title, o.due_on, o.days_overdue) AS line
          FROM overdue_as_of(DATE '2024-05-25')
               WITH ORDINALITY AS o (loan_id, membership_no, barcode, title,
                                     due_on, days_overdue, ord)) t;
    want := '3|M-0001|10000003|The Long Field|2024-05-01|24
2|M-0002|10000001|The Long Field|2024-05-23|2';
    IF got <> want THEN
        RAISE EXCEPTION E'overdue_as_of(2024-05-25) does not match\n--- expected ---\n%\n--- actual ---\n%',
            want, got;
    END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM overdue_as_of(DATE '2024-03-01');
    IF n <> 0 THEN RAISE EXCEPTION 'nothing was overdue on 2024-03-01, but % row(s) came back', n; END IF;

    SELECT count(*) INTO n FROM overdue_as_of(DATE '2024-05-23');
    IF n <> 1 THEN
        RAISE EXCEPTION 'on the due date itself a loan is not yet overdue; got % row(s), expected 1', n;
    END IF;
END $$;
