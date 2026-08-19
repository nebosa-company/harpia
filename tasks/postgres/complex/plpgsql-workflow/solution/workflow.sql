-- The reservation workflow. Write the functions and whatever the database
-- needs to keep them honest here.
-- This file is applied immediately after schema.sql.

-- A seat may sit in at most one live hold and at most one booking, even for a
-- writer that skips the functions below. "Booked at most once" is a plain
-- unique index; "held at most once at a time" depends on the hold's state, so
-- it cannot be an index predicate and needs a trigger.
CREATE UNIQUE INDEX booking_seats_one_per_seat ON booking_seats (seat_id);

CREATE FUNCTION hold_seats_exclusive() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM booking_seats bs WHERE bs.seat_id = NEW.seat_id) THEN
        RAISE EXCEPTION 'seat % is already booked', NEW.seat_id;
    END IF;
    IF EXISTS (
        SELECT 1
        FROM hold_seats hs
        JOIN holds h ON h.id = hs.hold_id
        WHERE hs.seat_id = NEW.seat_id
          AND hs.hold_id <> NEW.hold_id
          AND h.state = 'active')
    THEN
        RAISE EXCEPTION 'seat % is already held', NEW.seat_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER hold_seats_exclusive_trigger
    BEFORE INSERT ON hold_seats
    FOR EACH ROW EXECUTE FUNCTION hold_seats_exclusive();

CREATE FUNCTION hold_seats(
    p_event_id    integer,
    p_customer_ref text,
    p_seat_ids    integer[],
    p_now         timestamp,
    p_expires_at  timestamp
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    new_hold bigint;
    n        integer;
BEGIN
    IF p_seat_ids IS NULL OR array_length(p_seat_ids, 1) IS NULL THEN
        RAISE EXCEPTION 'a hold must name at least one seat';
    END IF;
    IF p_expires_at <= p_now THEN
        RAISE EXCEPTION 'a hold cannot expire at or before it is taken';
    END IF;

    SELECT count(*) INTO n
    FROM seats s
    WHERE s.id = ANY (p_seat_ids) AND s.event_id = p_event_id;
    IF n <> cardinality(p_seat_ids) THEN
        RAISE EXCEPTION 'one or more seats do not belong to event %', p_event_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM booking_seats bs WHERE bs.seat_id = ANY (p_seat_ids))
    THEN
        RAISE EXCEPTION 'one or more seats are already booked';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM hold_seats hs
        JOIN holds h ON h.id = hs.hold_id
        WHERE hs.seat_id = ANY (p_seat_ids)
          AND h.state = 'active'
          AND h.expires_at > p_now)
    THEN
        RAISE EXCEPTION 'one or more seats are already held';
    END IF;

    -- A hold that has run out of time is not in the way.
    UPDATE holds SET state = 'released'
    WHERE state = 'active' AND expires_at <= p_now;

    INSERT INTO holds (event_id, customer_ref, created_at, expires_at, state)
        VALUES (p_event_id, p_customer_ref, p_now, p_expires_at, 'active')
    RETURNING id INTO new_hold;

    INSERT INTO hold_seats (hold_id, seat_id)
    SELECT new_hold, unnest(p_seat_ids);

    RETURN new_hold;
END;
$$;

CREATE FUNCTION release_hold(p_hold_id bigint) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE st text;
BEGIN
    SELECT state INTO st FROM holds WHERE id = p_hold_id;
    IF st IS NULL THEN
        RAISE EXCEPTION 'hold % does not exist', p_hold_id;
    END IF;
    IF st = 'confirmed' THEN
        RAISE EXCEPTION 'hold % has already been confirmed and cannot be released', p_hold_id;
    END IF;
    UPDATE holds SET state = 'released' WHERE id = p_hold_id AND state = 'active';
END;
$$;

CREATE FUNCTION confirm_hold(p_hold_id bigint, p_now timestamp) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    h          holds%ROWTYPE;
    new_booking bigint;
BEGIN
    SELECT * INTO h FROM holds WHERE id = p_hold_id FOR UPDATE;
    IF h.id IS NULL THEN
        RAISE EXCEPTION 'hold % does not exist', p_hold_id;
    END IF;
    IF h.state = 'confirmed' THEN
        RAISE EXCEPTION 'hold % has already been confirmed', p_hold_id;
    END IF;
    IF h.state = 'released' THEN
        RAISE EXCEPTION 'hold % was released and can no longer be confirmed', p_hold_id;
    END IF;
    IF h.expires_at <= p_now THEN
        RAISE EXCEPTION 'hold % expired at % and can no longer be confirmed', p_hold_id, h.expires_at;
    END IF;

    INSERT INTO bookings (hold_id, event_id, customer_ref, confirmed_at)
        VALUES (h.id, h.event_id, h.customer_ref, p_now)
    RETURNING id INTO new_booking;

    INSERT INTO booking_seats (booking_id, seat_id)
    SELECT new_booking, hs.seat_id FROM hold_seats hs WHERE hs.hold_id = h.id;

    UPDATE holds SET state = 'confirmed' WHERE id = h.id;

    RETURN new_booking;
END;
$$;

CREATE FUNCTION expire_holds(p_now timestamp) RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE n integer;
BEGIN
    UPDATE holds SET state = 'released'
    WHERE state = 'active' AND expires_at <= p_now;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;

CREATE VIEW seat_availability AS
SELECT s.id           AS seat_id,
       s.event_id,
       s.row_label,
       s.seat_no,
       CASE
           WHEN EXISTS (SELECT 1 FROM booking_seats bs WHERE bs.seat_id = s.id)
               THEN 'booked'
           WHEN EXISTS (SELECT 1 FROM hold_seats hs
                        JOIN holds h ON h.id = hs.hold_id
                        WHERE hs.seat_id = s.id AND h.state = 'active')
               THEN 'held'
           ELSE 'free'
       END AS status
FROM seats s;
