-- Core: one audit row per write, carrying the before and after pictures.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM account_audit;
    IF n <> 0 THEN
        RAISE EXCEPTION 'the audit table already holds % row(s) before any write', n;
    END IF;
END $$;

DO $$
DECLARE got text; captured jsonb;
BEGIN
    INSERT INTO accounts (id, name, status, balance_cents)
        VALUES (4, 'Reserve', 'open', 300000);

    SELECT format('%s|%s|%s|%s', account_id, action, old_row IS NULL, changed_by) INTO got
    FROM account_audit ORDER BY id DESC LIMIT 1;
    IF got IS DISTINCT FROM '4|INSERT|t|system' THEN
        RAISE EXCEPTION 'the insert was audited as %, expected 4|INSERT|t|system',
            coalesce(got, '<nothing>');
    END IF;

    SELECT new_row INTO captured FROM account_audit ORDER BY id DESC LIMIT 1;
    IF captured IS DISTINCT FROM
       '{"id": 4, "name": "Reserve", "status": "open", "balance_cents": 300000}'::jsonb THEN
        RAISE EXCEPTION 'the insert captured new_row = %', coalesce(captured::text, '<null>');
    END IF;
END $$;

DO $$
DECLARE old_j jsonb; new_j jsonb; got text;
BEGIN
    UPDATE accounts SET balance_cents = 275000, status = 'frozen' WHERE id = 4;

    SELECT format('%s|%s', account_id, action), old_row, new_row INTO got, old_j, new_j
    FROM account_audit ORDER BY id DESC LIMIT 1;
    IF got IS DISTINCT FROM '4|UPDATE' THEN
        RAISE EXCEPTION 'the update was audited as %', coalesce(got, '<nothing>');
    END IF;
    IF old_j IS DISTINCT FROM
       '{"id": 4, "name": "Reserve", "status": "open", "balance_cents": 300000}'::jsonb THEN
        RAISE EXCEPTION 'the update captured old_row = %', coalesce(old_j::text, '<null>');
    END IF;
    IF new_j IS DISTINCT FROM
       '{"id": 4, "name": "Reserve", "status": "frozen", "balance_cents": 275000}'::jsonb THEN
        RAISE EXCEPTION 'the update captured new_row = %', coalesce(new_j::text, '<null>');
    END IF;
END $$;

DO $$
DECLARE old_j jsonb; got text;
BEGIN
    DELETE FROM accounts WHERE id = 4;

    SELECT format('%s|%s|%s', account_id, action, new_row IS NULL), old_row INTO got, old_j
    FROM account_audit ORDER BY id DESC LIMIT 1;
    IF got IS DISTINCT FROM '4|DELETE|t' THEN
        RAISE EXCEPTION 'the delete was audited as %, expected 4|DELETE|t', coalesce(got, '<nothing>');
    END IF;
    IF old_j IS DISTINCT FROM
       '{"id": 4, "name": "Reserve", "status": "frozen", "balance_cents": 275000}'::jsonb THEN
        RAISE EXCEPTION 'the delete captured old_row = %', coalesce(old_j::text, '<null>');
    END IF;
END $$;

DO $$
DECLARE got text; n bigint;
BEGIN
    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT action AS line FROM account_audit ORDER BY id) t;
    IF got <> 'INSERT,UPDATE,DELETE' THEN
        RAISE EXCEPTION 'the audit trail reads %, expected INSERT,UPDATE,DELETE', got;
    END IF;

    SELECT count(*) INTO n FROM account_audit WHERE changed_at IS NULL;
    IF n <> 0 THEN RAISE EXCEPTION '% audit row(s) have no changed_at', n; END IF;
END $$;
