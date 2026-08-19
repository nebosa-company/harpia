-- Edge: empty orders, cancelled orders, and liveness of the view.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n
    FROM monthly_revenue
    WHERE month = DATE '2024-03-01' AND region = 'North';
    IF n <> 0 THEN
        RAISE EXCEPTION 'an order with no line items produced a monthly_revenue row for 2024-03 North';
    END IF;
END $$;

DO $$
DECLARE before_net bigint; after_net bigint;
BEGIN
    SELECT coalesce(sum(net_cents), 0) INTO before_net FROM monthly_revenue;
    INSERT INTO orders (id, customer_id, placed_on, status)
        VALUES (900, 5, DATE '2024-04-04', 'cancelled');
    INSERT INTO order_items (id, order_id, sku, quantity, unit_price_cents, discount_cents)
        VALUES (900, 900, 'Z-9', 5, 10000, 1000);
    SELECT coalesce(sum(net_cents), 0) INTO after_net FROM monthly_revenue;
    IF after_net <> before_net THEN
        RAISE EXCEPTION 'a cancelled order changed reported revenue (% -> %)', before_net, after_net;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    INSERT INTO orders (id, customer_id, placed_on, status)
        VALUES (901, 5, DATE '2024-04-06', 'placed');
    INSERT INTO order_items (id, order_id, sku, quantity, unit_price_cents, discount_cents) VALUES
        (901, 901, 'Z-9', 3, 10000, 2500),
        (902, 901, 'Y-8', 1,  4000,    0);
    SELECT format('%s|%s|%s', order_count, gross_cents, net_cents) INTO got
    FROM monthly_revenue
    WHERE month = DATE '2024-04-01' AND region = 'East';
    IF got IS DISTINCT FROM '1|34000|31500' THEN
        RAISE EXCEPTION 'the 2024-04 East row was %, expected 1|34000|31500', coalesce(got, '<missing>');
    END IF;
END $$;
