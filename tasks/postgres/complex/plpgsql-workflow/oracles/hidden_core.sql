-- Core: the happy path, and the three ways a hold stops being confirmable.

CREATE FUNCTION _hidden_raises(stmt text) RETURNS boolean
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION
        WHEN undefined_table OR undefined_column OR undefined_function OR syntax_error THEN
            RAISE;
        WHEN OTHERS THEN
            RETURN true;
    END;
    RETURN false;
END $$;

DO $$
DECLARE h bigint; b bigint; got text;
BEGIN
    h := hold_seats(1, 'cust-a', ARRAY[101, 102, 103],
                    TIMESTAMP '2024-09-01 10:00:00', TIMESTAMP '2024-09-01 10:15:00');
    IF h IS NULL THEN RAISE EXCEPTION 'hold_seats returned no hold id'; END IF;

    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT format('%s:%s', seat_id, status) AS line
          FROM seat_availability WHERE event_id = 1 AND seat_id <= 105 ORDER BY seat_id) t;
    IF got <> '101:held,102:held,103:held,104:free,105:free' THEN
        RAISE EXCEPTION 'after the hold row A reads %', got;
    END IF;

    b := confirm_hold(h, TIMESTAMP '2024-09-01 10:05:00');
    IF b IS NULL THEN RAISE EXCEPTION 'confirm_hold returned no booking id'; END IF;

    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT format('%s:%s', seat_id, status) AS line
          FROM seat_availability WHERE event_id = 1 AND seat_id <= 105 ORDER BY seat_id) t;
    IF got <> '101:booked,102:booked,103:booked,104:free,105:free' THEN
        RAISE EXCEPTION 'after confirming row A reads %', got;
    END IF;

    SELECT format('%s|%s|%s', state, customer_ref, event_id) INTO got FROM holds WHERE id = h;
    IF got IS DISTINCT FROM 'confirmed|cust-a|1' THEN
        RAISE EXCEPTION 'the confirmed hold reads %', coalesce(got, '<missing>');
    END IF;

    SELECT coalesce(string_agg(seat_id::text, ','), '<no rows>') INTO got
    FROM (SELECT seat_id FROM booking_seats WHERE booking_id = b ORDER BY seat_id) t;
    IF got <> '101,102,103' THEN
        RAISE EXCEPTION 'the booking carries seats %', got;
    END IF;
END $$;

DO $$
DECLARE h bigint; before_holds bigint; after_holds bigint;
BEGIN
    -- A seat that is already booked cannot be held again, and nothing is
    -- left behind by the attempt.
    SELECT count(*) INTO before_holds FROM holds;
    IF NOT _hidden_raises(
        'SELECT hold_seats(1, ''cust-b'', ARRAY[103, 104], '
        'TIMESTAMP ''2024-09-01 11:00:00'', TIMESTAMP ''2024-09-01 11:15:00'')')
    THEN
        RAISE EXCEPTION 'a booked seat was held again';
    END IF;
    SELECT count(*) INTO after_holds FROM holds;
    IF after_holds <> before_holds THEN
        RAISE EXCEPTION 'the refused hold left % extra hold row(s) behind', after_holds - before_holds;
    END IF;
    IF EXISTS (SELECT 1 FROM seat_availability WHERE seat_id = 104 AND status <> 'free') THEN
        RAISE EXCEPTION 'the refused hold locked seat 104 anyway';
    END IF;

    -- The seats that were free are still holdable on their own.
    h := hold_seats(1, 'cust-b', ARRAY[104, 105],
                    TIMESTAMP '2024-09-01 11:00:00', TIMESTAMP '2024-09-01 11:15:00');
    IF h IS NULL THEN RAISE EXCEPTION 'the free seats could not be held'; END IF;
END $$;

DO $$
DECLARE h bigint; n integer; got text;
BEGIN
    -- An expired hold cannot be confirmed, and the seats come back.
    h := hold_seats(2, 'cust-c', ARRAY[201, 202],
                    TIMESTAMP '2024-09-01 12:00:00', TIMESTAMP '2024-09-01 12:10:00');

    IF NOT _hidden_raises(format('SELECT confirm_hold(%s, TIMESTAMP ''2024-09-01 12:30:00'')', h)) THEN
        RAISE EXCEPTION 'an expired hold was confirmed';
    END IF;

    n := expire_holds(TIMESTAMP '2024-09-01 12:30:00');
    IF n < 1 THEN RAISE EXCEPTION 'expire_holds swept % holds, expected at least 1', n; END IF;

    SELECT state INTO got FROM holds WHERE id = h;
    IF got IS DISTINCT FROM 'released' THEN
        RAISE EXCEPTION 'the expired hold is in state %, expected released', coalesce(got, '<missing>');
    END IF;

    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT format('%s:%s', seat_id, status) AS line
          FROM seat_availability WHERE seat_id IN (201, 202) ORDER BY seat_id) t;
    IF got <> '201:free,202:free' THEN
        RAISE EXCEPTION 'after expiry the seats read %', got;
    END IF;
END $$;

DO $$
DECLARE h bigint;
BEGIN
    -- A released hold cannot be confirmed, and confirming twice is refused.
    h := hold_seats(2, 'cust-d', ARRAY[203],
                    TIMESTAMP '2024-09-02 09:00:00', TIMESTAMP '2024-09-02 09:15:00');
    PERFORM release_hold(h);
    IF NOT _hidden_raises(format('SELECT confirm_hold(%s, TIMESTAMP ''2024-09-02 09:05:00'')', h)) THEN
        RAISE EXCEPTION 'a released hold was confirmed';
    END IF;

    h := hold_seats(2, 'cust-e', ARRAY[204],
                    TIMESTAMP '2024-09-02 09:00:00', TIMESTAMP '2024-09-02 09:15:00');
    PERFORM confirm_hold(h, TIMESTAMP '2024-09-02 09:05:00');
    IF NOT _hidden_raises(format('SELECT confirm_hold(%s, TIMESTAMP ''2024-09-02 09:06:00'')', h)) THEN
        RAISE EXCEPTION 'the same hold was confirmed twice';
    END IF;
END $$;
