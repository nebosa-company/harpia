-- Edge: the refunds migration.

CREATE FUNCTION _hidden_must_reject(stmt text, what text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION
        WHEN undefined_table OR undefined_column OR undefined_function OR syntax_error THEN
            RAISE;
        WHEN OTHERS THEN
            RETURN;
    END;
    RAISE EXCEPTION 'the database accepted %', what;
END $$;

DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(c.col, ', ' ORDER BY c.col) INTO missing
    FROM (VALUES ('id'), ('payment_id'), ('amount_cents'), ('refunded_on'), ('reason')) AS c (col)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'refunds' AND column_name = c.col);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'refunds is missing column(s): %', missing;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Nothing refunded yet: every order that was paid for reports its payments.
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', order_id, paid_cents, refunded_cents, net_cents) AS line
          FROM refund_summary ORDER BY order_id) t;
    IF got <> '1|12000|0|12000
2|8000|0|8000
3|15000|0|15000
5|9000|0|9000' THEN
        RAISE EXCEPTION E'refund_summary before any refund reads\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason)
        VALUES (3, 5000, DATE '2024-04-01', 'damaged in transit');

    SELECT format('%s|%s|%s', paid_cents, refunded_cents, net_cents) INTO got
    FROM refund_summary WHERE order_id = 3;
    IF got IS DISTINCT FROM '15000|5000|10000' THEN
        RAISE EXCEPTION 'order 3 reads %, expected 15000|5000|10000', coalesce(got, '<missing>');
    END IF;

    -- Partial refunds accumulate up to the payment, and no further.
    INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason)
        VALUES (3, 10000, DATE '2024-04-05', 'remainder');

    SELECT format('%s|%s|%s', paid_cents, refunded_cents, net_cents) INTO got
    FROM refund_summary WHERE order_id = 3;
    IF got IS DISTINCT FROM '15000|15000|0' THEN
        RAISE EXCEPTION 'order 3 reads %, expected 15000|15000|0', coalesce(got, '<missing>');
    END IF;

    PERFORM _hidden_must_reject(
        'INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason) '
        'VALUES (3, 1, DATE ''2024-04-06'', ''one too many'')',
        'a refund taking the total past what was paid');
END $$;

DO $$
BEGIN
    PERFORM _hidden_must_reject(
        'INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason) '
        'VALUES (1, 12001, DATE ''2024-04-01'', ''more than was paid'')',
        'a refund larger than the payment it is against');
    PERFORM _hidden_must_reject(
        'INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason) '
        'VALUES (1, 0, DATE ''2024-04-01'', ''nothing'')',
        'a refund of zero');
    PERFORM _hidden_must_reject(
        'INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason) '
        'VALUES (1, -500, DATE ''2024-04-01'', ''negative'')',
        'a refund of a negative amount');
    PERFORM _hidden_must_reject(
        'INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason) '
        'VALUES (4242, 100, DATE ''2024-04-01'', ''ghost payment'')',
        'a refund against a payment that does not exist');

    -- Refunding exactly the payment is allowed.
    INSERT INTO refunds (payment_id, amount_cents, refunded_on, reason)
        VALUES (2, 8000, DATE '2024-04-02', 'returned');
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Refunds follow their payment out, and a payment follows its order.
    SELECT count(*) INTO n FROM refunds;
    IF n <> 3 THEN RAISE EXCEPTION 'expected 3 refunds, found %', n; END IF;

    DELETE FROM orders WHERE id = 3;

    SELECT count(*) INTO n FROM payments WHERE order_id = 3;
    IF n <> 0 THEN RAISE EXCEPTION 'deleting order 3 left % payment(s)', n; END IF;
    SELECT count(*) INTO n FROM refunds WHERE payment_id = 3;
    IF n <> 0 THEN RAISE EXCEPTION 'deleting order 3 left % refund(s) stranded', n; END IF;
    SELECT count(*) INTO n FROM refunds;
    IF n <> 1 THEN RAISE EXCEPTION 'expected 1 surviving refund, found %', n; END IF;

    IF EXISTS (SELECT 1 FROM refund_summary WHERE order_id = 3) THEN
        RAISE EXCEPTION 'refund_summary still reports an order that is gone';
    END IF;
END $$;
