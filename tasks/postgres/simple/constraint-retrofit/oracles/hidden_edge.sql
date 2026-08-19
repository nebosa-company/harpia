-- Edge: the seed still loads, and only one live subscription per account.

CREATE FUNCTION _hidden_must_reject(stmt text, what text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION
        WHEN check_violation OR unique_violation OR foreign_key_violation
          OR not_null_violation OR exclusion_violation
          OR numeric_value_out_of_range OR string_data_right_truncation THEN
            RETURN;
    END;
    RAISE EXCEPTION 'the database accepted %', what;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM plans;
    IF n <> 3 THEN RAISE EXCEPTION 'expected 3 seeded plans, found %', n; END IF;
    SELECT count(*) INTO n FROM subscriptions;
    IF n <> 6 THEN RAISE EXCEPTION 'expected 6 seeded subscriptions, found %', n; END IF;
END $$;

DO $$
DECLARE base text := 'INSERT INTO subscriptions '
                     '(id, account_ref, plan_code, seats, started_on, ended_on, status, discount_pct) VALUES ';
BEGIN
    PERFORM _hidden_must_reject(
        base || '(920, ''acct-1001'', ''team'', 4, DATE ''2024-06-01'', NULL, ''active'', 0)',
        'a second live subscription for an account that already has one');
    PERFORM _hidden_must_reject(
        base || '(921, ''acct-1005'', ''team'', 4, DATE ''2024-06-01'', NULL, ''trialing'', 0)',
        'a trialing subscription alongside a paused one for the same account');
    PERFORM _hidden_must_reject(
        base || '(922, ''   '', ''team'', 4, DATE ''2024-06-01'', NULL, ''active'', 0)',
        'a subscription whose account reference is only whitespace');
    PERFORM _hidden_must_reject(
        base || '(923, '''', ''team'', 4, DATE ''2024-06-01'', NULL, ''active'', 0)',
        'a subscription with an empty account reference');
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Any number of cancelled subscriptions may pile up on one account.
    INSERT INTO subscriptions
        (id, account_ref, plan_code, seats, started_on, ended_on, status, discount_pct) VALUES
        (930, 'acct-1003', 'team', 4, DATE '2021-01-01', DATE '2021-12-31', 'cancelled', 0),
        (931, 'acct-1003', 'team', 4, DATE '2020-01-01', DATE '2020-12-31', 'cancelled', 0);
    SELECT count(*) INTO n FROM subscriptions WHERE account_ref = 'acct-1003';
    IF n <> 4 THEN RAISE EXCEPTION 'expected 4 subscriptions for acct-1003, found %', n; END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Once the live one is cancelled, the account may start a new subscription.
    UPDATE subscriptions SET status = 'cancelled', ended_on = DATE '2024-05-31' WHERE id = 1;
    INSERT INTO subscriptions
        (id, account_ref, plan_code, seats, started_on, ended_on, status, discount_pct)
        VALUES (940, 'acct-1001', 'scale', 30, DATE '2024-06-01', NULL, 'active', 0);
    SELECT count(*) INTO n FROM subscriptions WHERE account_ref = 'acct-1001' AND status <> 'cancelled';
    IF n <> 1 THEN RAISE EXCEPTION 'expected exactly 1 live subscription for acct-1001, found %', n; END IF;
END $$;
