-- Core: the per-row billing rules the database now has to enforce.

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
DECLARE base text := 'INSERT INTO subscriptions '
                     '(id, account_ref, plan_code, seats, started_on, ended_on, status, discount_pct) VALUES ';
BEGIN
    PERFORM _hidden_must_reject(
        base || '(910, ''acct-9910'', ''team'', 0, DATE ''2024-01-01'', NULL, ''active'', 0)',
        'a subscription with 0 seats');
    PERFORM _hidden_must_reject(
        base || '(911, ''acct-9911'', ''team'', -3, DATE ''2024-01-01'', NULL, ''active'', 0)',
        'a subscription with a negative seat count');
    PERFORM _hidden_must_reject(
        base || '(912, ''acct-9912'', ''team'', 501, DATE ''2024-01-01'', NULL, ''active'', 0)',
        'a subscription with 501 seats');
    PERFORM _hidden_must_reject(
        base || '(913, ''acct-9913'', ''team'', 5, DATE ''2024-01-01'', NULL, ''expired'', 0)',
        'a subscription with an unknown status');
    PERFORM _hidden_must_reject(
        base || '(914, ''acct-9914'', ''team'', 5, DATE ''2024-03-01'', DATE ''2024-02-01'', ''cancelled'', 0)',
        'a subscription that ended before it started');
    PERFORM _hidden_must_reject(
        base || '(915, ''acct-9915'', ''team'', 5, DATE ''2024-01-01'', NULL, ''active'', -0.01)',
        'a negative discount');
    PERFORM _hidden_must_reject(
        base || '(916, ''acct-9916'', ''team'', 5, DATE ''2024-01-01'', NULL, ''active'', 100.01)',
        'a discount above 100 percent');
    PERFORM _hidden_must_reject(
        'INSERT INTO plans (code, monthly_cents) VALUES (''broken'', -1)',
        'a plan with a negative price');
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- The legitimate boundary values must still go in.
    INSERT INTO subscriptions
        (id, account_ref, plan_code, seats, started_on, ended_on, status, discount_pct) VALUES
        (900, 'acct-9900', 'team',   1, DATE '2024-01-01', NULL,              'active',     0.00),
        (901, 'acct-9901', 'team', 500, DATE '2024-01-01', NULL,              'active',     0.00),
        (902, 'acct-9902', 'team',   5, DATE '2024-01-01', NULL,              'active',   100.00),
        (903, 'acct-9903', 'team',   5, DATE '2024-01-01', DATE '2024-01-01', 'paused',     0.00),
        (904, 'acct-9904', 'starter', 9, DATE '2024-01-01', NULL,             'trialing',   0.00);

    SELECT count(*) INTO n FROM subscriptions WHERE id >= 900;
    IF n <> 5 THEN RAISE EXCEPTION 'expected 5 accepted boundary rows, found %', n; END IF;
END $$;
