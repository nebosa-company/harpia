-- Core: the chain applied, and the data it left behind is exactly right.

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
DECLARE got text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', id, email, name) AS line
          FROM customers ORDER BY id) t;
    IF got <> '1|rosa@example.com|Rosa Klein
2|imre@example.org|Imre Bako
4|nadia@example.net|Nadia Farouk' THEN
        RAISE EXCEPTION E'customers ended up as\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', id, customer_id, status, total_cents) AS line
          FROM orders ORDER BY id) t;
    IF got <> '1|1|shipped|12000
2|2|shipped|8000
3|1|shipped|15000
4|4|placed|5000
5|1|shipped|9000
7|1|placed|7000' THEN
        RAISE EXCEPTION E'orders ended up as\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', id, order_id, amount_cents, method) AS line
          FROM payments ORDER BY id) t;
    IF got <> '1|1|12000|card
2|2|8000|card
3|3|15000|transfer
4|5|9000|card' THEN
        RAISE EXCEPTION E'payments ended up as\n%', got;
    END IF;
END $$;

DO $$
BEGIN
    -- 002: the status column is mandatory, defaulted, and restricted.
    INSERT INTO orders (id, customer_id, placed_on, total_cents)
        VALUES (900, 1, DATE '2024-06-01', 1000);
    IF (SELECT status FROM orders WHERE id = 900) <> 'placed' THEN
        RAISE EXCEPTION 'a new order did not default to placed';
    END IF;

    PERFORM _hidden_must_reject(
        'INSERT INTO orders (id, customer_id, placed_on, total_cents, status) '
        'VALUES (901, 1, DATE ''2024-06-01'', 1000, ''refunded'')',
        'an order in an unknown status');
    PERFORM _hidden_must_reject(
        'UPDATE orders SET status = NULL WHERE id = 900',
        'an order with no status at all');
END $$;

DO $$
BEGIN
    -- 003: one customer per address, however it is spelled.
    PERFORM _hidden_must_reject(
        'INSERT INTO customers (id, email, name) VALUES (900, ''Rosa@EXAMPLE.com'', ''Impostor'')',
        'a second customer on an address that is already taken');

    -- A genuinely new address is still fine.
    INSERT INTO customers (id, email, name) VALUES (901, 'vera@example.ro', 'Vera Popa');
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- 004: the relationships are real, and payments follow their order out.
    PERFORM _hidden_must_reject(
        'INSERT INTO orders (id, customer_id, placed_on, total_cents) '
        'VALUES (902, 4242, DATE ''2024-06-01'', 1000)',
        'an order naming a customer that does not exist');
    PERFORM _hidden_must_reject(
        'INSERT INTO payments (id, order_id, amount_cents, method) '
        'VALUES (900, 4242, 1000, ''card'')',
        'a payment naming an order that does not exist');

    DELETE FROM orders WHERE id = 5;
    SELECT count(*) INTO n FROM payments WHERE order_id = 5;
    IF n <> 0 THEN
        RAISE EXCEPTION 'deleting an order left % of its payments behind', n;
    END IF;
    SELECT count(*) INTO n FROM payments;
    IF n <> 3 THEN
        RAISE EXCEPTION 'expected 3 payments after the cascade, found %', n;
    END IF;
END $$;
