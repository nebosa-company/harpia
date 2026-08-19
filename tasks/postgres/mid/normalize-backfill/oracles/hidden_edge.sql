-- Edge: the new tables carry the integrity the wide table never had.

CREATE FUNCTION _hidden_must_reject(stmt text, what text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION
        WHEN check_violation OR unique_violation OR foreign_key_violation
          OR not_null_violation OR exclusion_violation THEN
            RETURN;
    END;
    RAISE EXCEPTION 'the database accepted %', what;
END $$;

DO $$
BEGIN
    PERFORM _hidden_must_reject(
        'INSERT INTO order_lines (order_id, line_no, sku, quantity, unit_price_cents) '
        'VALUES (999999, 1, ''X-1'', 1, 100)',
        'an order line belonging to an order that does not exist');

    PERFORM _hidden_must_reject(
        'INSERT INTO orders (order_ref, customer_id, placed_on, status) '
        'VALUES (''ORD-9999'', 999999, DATE ''2024-04-01'', ''placed'')',
        'an order belonging to a customer that does not exist');

    PERFORM _hidden_must_reject(
        'INSERT INTO customers (email, name) VALUES (''rosa@example.com'', ''Someone Else'')',
        'a second customer row for an address that already has one');

    PERFORM _hidden_must_reject(
        'INSERT INTO orders (order_ref, customer_id, placed_on, status) '
        'SELECT ''ORD-1001'', customer_id, DATE ''2024-04-01'', ''placed'' FROM orders LIMIT 1',
        'a second order carrying an order reference that already exists');
END $$;

DO $$
DECLARE oid_1003 integer;
BEGIN
    SELECT id INTO oid_1003 FROM orders WHERE order_ref = 'ORD-1003';
    PERFORM _hidden_must_reject(
        format('INSERT INTO order_lines (order_id, line_no, sku, quantity, unit_price_cents) '
               'VALUES (%s, 1, ''X-1'', 1, 100)', oid_1003),
        'a second line 1 on an order that already has one');
END $$;

DO $$
DECLARE got text; cust integer; ord integer;
BEGIN
    -- New business written into the normalised tables shows up in orders_wide.
    INSERT INTO customers (email, name) VALUES ('vera@example.ro', 'Vera Popa')
    RETURNING id INTO cust;
    INSERT INTO orders (order_ref, customer_id, placed_on, status)
        VALUES ('ORD-2001', cust, DATE '2024-04-02', 'placed')
    RETURNING id INTO ord;
    INSERT INTO order_lines (order_id, line_no, sku, quantity, unit_price_cents) VALUES
        (ord, 1, 'LAMP-01', 4, 4900),
        (ord, 2, 'MAT-01',  1, 7900);

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s|%s|%s|%s',
                        customer_email, customer_name, placed_on, status,
                        line_no, sku, quantity, unit_price_cents) AS line
          FROM orders_wide WHERE order_ref = 'ORD-2001' ORDER BY line_no) t;

    IF got <> 'vera@example.ro|Vera Popa|2024-04-02|placed|1|LAMP-01|4|4900
vera@example.ro|Vera Popa|2024-04-02|placed|2|MAT-01|1|7900' THEN
        RAISE EXCEPTION E'the new order reads back through orders_wide as\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Correcting a customer's name once fixes every one of their orders.
    UPDATE customers SET name = 'Rosa Klein-Vos' WHERE email = 'rosa@example.com';
    SELECT coalesce(string_agg(DISTINCT customer_name, ','), '<no rows>') INTO got
    FROM orders_wide WHERE customer_email = 'rosa@example.com';
    IF got <> 'Rosa Klein-Vos' THEN
        RAISE EXCEPTION 'after one rename orders_wide reports the name(s) %', got;
    END IF;
END $$;
