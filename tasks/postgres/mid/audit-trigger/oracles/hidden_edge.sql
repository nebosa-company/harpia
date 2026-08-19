-- Edge: the actor setting, no-op updates, and multi-row statements.

DO $$
DECLARE got text;
BEGIN
    PERFORM set_config('app.actor', 'ines@example.com', false);
    UPDATE accounts SET balance_cents = balance_cents - 1000 WHERE id = 1;

    SELECT changed_by INTO got FROM account_audit ORDER BY id DESC LIMIT 1;
    IF got IS DISTINCT FROM 'ines@example.com' THEN
        RAISE EXCEPTION 'changed_by was %, expected ines@example.com', coalesce(got, '<nothing>');
    END IF;

    PERFORM set_config('app.actor', '', false);
    UPDATE accounts SET balance_cents = balance_cents - 1000 WHERE id = 1;
    SELECT changed_by INTO got FROM account_audit ORDER BY id DESC LIMIT 1;
    IF got IS DISTINCT FROM 'system' THEN
        RAISE EXCEPTION 'with no actor set changed_by was %, expected system',
            coalesce(got, '<nothing>');
    END IF;
END $$;

DO $$
DECLARE before_n bigint; after_n bigint;
BEGIN
    -- An update that changes nothing is not a change.
    SELECT count(*) INTO before_n FROM account_audit;
    UPDATE accounts SET balance_cents = balance_cents, status = status, name = name;
    SELECT count(*) INTO after_n FROM account_audit;
    IF after_n <> before_n THEN
        RAISE EXCEPTION 'an update that changed no values wrote % audit row(s)', after_n - before_n;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- One statement touching three rows writes three audit rows.
    DELETE FROM account_audit;
    UPDATE accounts SET status = 'closed';

    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT format('%s:%s', account_id, action) AS line
          FROM account_audit ORDER BY account_id) t;
    IF got <> '1:UPDATE,2:UPDATE,3:UPDATE' THEN
        RAISE EXCEPTION 'a three-row update produced %', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- The old picture of a delete is the row as it stood, not as it began.
    DELETE FROM account_audit;
    DELETE FROM accounts WHERE id = 3;
    SELECT format('%s|%s|%s', action, old_row ->> 'status', old_row ->> 'balance_cents') INTO got
    FROM account_audit ORDER BY id DESC LIMIT 1;
    IF got IS DISTINCT FROM 'DELETE|closed|500000' THEN
        RAISE EXCEPTION 'the delete captured %, expected DELETE|closed|500000',
            coalesce(got, '<nothing>');
    END IF;
END $$;
