-- Edge: contention between holds, argument validation, and the invariant
-- holding against writers that never call the functions.

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
DECLARE h bigint;
BEGIN
    -- Two customers reaching for an overlapping pair: the second is refused
    -- outright rather than getting the seat that is still free.
    h := hold_seats(1, 'first', ARRAY[101, 102],
                    TIMESTAMP '2024-09-01 10:00:00', TIMESTAMP '2024-09-01 10:15:00');

    IF NOT _hidden_raises(
        'SELECT hold_seats(1, ''second'', ARRAY[102, 103], '
        'TIMESTAMP ''2024-09-01 10:01:00'', TIMESTAMP ''2024-09-01 10:16:00'')')
    THEN
        RAISE EXCEPTION 'an overlapping hold was granted';
    END IF;

    IF EXISTS (SELECT 1 FROM seat_availability WHERE seat_id = 103 AND status <> 'free') THEN
        RAISE EXCEPTION 'the refused hold took seat 103 anyway';
    END IF;

    -- Once the first hold goes away the seats are up for grabs again.
    PERFORM release_hold(h);
    h := hold_seats(1, 'second', ARRAY[102, 103],
                    TIMESTAMP '2024-09-01 10:02:00', TIMESTAMP '2024-09-01 10:17:00');
    IF h IS NULL THEN RAISE EXCEPTION 'the seats were not free after the release'; END IF;
    PERFORM release_hold(h);
END $$;

DO $$
BEGIN
    -- Arguments are checked.
    IF NOT _hidden_raises(
        'SELECT hold_seats(1, ''x'', ARRAY[]::integer[], '
        'TIMESTAMP ''2024-09-01 10:00:00'', TIMESTAMP ''2024-09-01 10:15:00'')')
    THEN
        RAISE EXCEPTION 'a hold over no seats was granted';
    END IF;

    IF NOT _hidden_raises(
        'SELECT hold_seats(1, ''x'', ARRAY[201], '
        'TIMESTAMP ''2024-09-01 10:00:00'', TIMESTAMP ''2024-09-01 10:15:00'')')
    THEN
        RAISE EXCEPTION 'a hold naming another event''s seat was granted';
    END IF;

    IF NOT _hidden_raises(
        'SELECT hold_seats(1, ''x'', ARRAY[104], '
        'TIMESTAMP ''2024-09-01 10:00:00'', TIMESTAMP ''2024-09-01 10:00:00'')')
    THEN
        RAISE EXCEPTION 'a hold that expires the moment it is taken was granted';
    END IF;

    IF NOT _hidden_raises('SELECT confirm_hold(999999, TIMESTAMP ''2024-09-01 10:00:00'')') THEN
        RAISE EXCEPTION 'confirming a hold that does not exist succeeded';
    END IF;
    IF NOT _hidden_raises('SELECT release_hold(999999)') THEN
        RAISE EXCEPTION 'releasing a hold that does not exist succeeded';
    END IF;
END $$;

DO $$
DECLARE h bigint; st text;
BEGIN
    -- Releasing twice is harmless; releasing a confirmed hold is not allowed.
    h := hold_seats(2, 'idem', ARRAY[251],
                    TIMESTAMP '2024-09-03 09:00:00', TIMESTAMP '2024-09-03 09:15:00');
    PERFORM release_hold(h);
    PERFORM release_hold(h);
    SELECT state INTO st FROM holds WHERE id = h;
    IF st <> 'released' THEN
        RAISE EXCEPTION 'after two releases the hold is in state %', st;
    END IF;

    h := hold_seats(2, 'done', ARRAY[252],
                    TIMESTAMP '2024-09-03 09:00:00', TIMESTAMP '2024-09-03 09:15:00');
    PERFORM confirm_hold(h, TIMESTAMP '2024-09-03 09:05:00');
    IF NOT _hidden_raises(format('SELECT release_hold(%s)', h)) THEN
        RAISE EXCEPTION 'a confirmed hold was released';
    END IF;
END $$;

DO $$
DECLARE h bigint; n integer;
BEGIN
    -- expire_holds only touches holds that have actually run out.
    h := hold_seats(2, 'live', ARRAY[253],
                    TIMESTAMP '2024-09-04 09:00:00', TIMESTAMP '2024-09-04 09:30:00');
    n := expire_holds(TIMESTAMP '2024-09-04 09:10:00');
    IF n <> 0 THEN RAISE EXCEPTION 'expire_holds swept % live hold(s)', n; END IF;
    IF (SELECT state FROM holds WHERE id = h) <> 'active' THEN
        RAISE EXCEPTION 'a hold that had not run out was released';
    END IF;

    n := expire_holds(TIMESTAMP '2024-09-04 09:30:00');
    IF n <> 1 THEN RAISE EXCEPTION 'expire_holds swept % holds at the expiry instant, expected 1', n; END IF;
END $$;

DO $$
DECLARE h bigint; other bigint;
BEGIN
    -- The invariant survives a writer that goes round the functions.
    h := hold_seats(1, 'guarded', ARRAY[105],
                    TIMESTAMP '2024-09-05 09:00:00', TIMESTAMP '2024-09-05 09:15:00');
    other := hold_seats(1, 'neighbour', ARRAY[104],
                    TIMESTAMP '2024-09-05 09:00:00', TIMESTAMP '2024-09-05 09:15:00');

    IF NOT _hidden_raises(
        format('INSERT INTO hold_seats (hold_id, seat_id) VALUES (%s, 105)', other))
    THEN
        RAISE EXCEPTION 'a seat already under a live hold was written into a second hold by hand';
    END IF;

    PERFORM confirm_hold(h, TIMESTAMP '2024-09-05 09:05:00');
    PERFORM confirm_hold(other, TIMESTAMP '2024-09-05 09:05:00');

    IF NOT _hidden_raises(
        format('INSERT INTO booking_seats (booking_id, seat_id) VALUES (%s, 105)',
               (SELECT id FROM bookings WHERE customer_ref = 'neighbour')))
    THEN
        RAISE EXCEPTION 'a seat was written into a second booking by hand';
    END IF;
END $$;
