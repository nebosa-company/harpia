-- Edge: the size threshold, and counting accounts rather than payments.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM cohort_summary WHERE cohort_month = DATE '2023-02-01';
    IF n <> 0 THEN
        RAISE EXCEPTION 'the 2023-02 cohort has only 2 accounts and must not be reported';
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    INSERT INTO accounts (id, name, signed_up_on, plan)
        VALUES (14, 'Nutmeg', DATE '2023-02-25', 'team');
    INSERT INTO payments (id, account_id, paid_on, amount_cents)
        VALUES (11, 14, DATE '2023-03-01', 30000);
    SELECT format('%s|%s|%s|%s', accounts, paying_accounts, total_cents, avg_cents) INTO got
    FROM cohort_summary WHERE cohort_month = DATE '2023-02-01';
    IF got IS DISTINCT FROM '3|2|39900|13300.00' THEN
        RAISE EXCEPTION 'the 2023-02 cohort was %, expected 3|2|39900|13300.00', coalesce(got, '<missing>');
    END IF;
END $$;

DO $$
DECLARE before_paying bigint; after_paying bigint; after_total bigint;
BEGIN
    SELECT paying_accounts INTO before_paying
    FROM cohort_summary WHERE cohort_month = DATE '2023-01-01';

    INSERT INTO payments (id, account_id, paid_on, amount_cents)
        VALUES (12, 1, DATE '2023-06-01', 9900);

    SELECT paying_accounts, total_cents INTO after_paying, after_total
    FROM cohort_summary WHERE cohort_month = DATE '2023-01-01';

    IF after_paying <> before_paying THEN
        RAISE EXCEPTION 'a second payment from the same account moved paying_accounts (% -> %)',
            before_paying, after_paying;
    END IF;
    IF after_total <> 179400 THEN
        RAISE EXCEPTION 'the 2023-01 total_cents was %, expected 179400', after_total;
    END IF;
END $$;
