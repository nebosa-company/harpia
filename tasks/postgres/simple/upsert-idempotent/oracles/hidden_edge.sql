-- Edge: several shipments per sku, warehouses kept apart, receipt dates.

DO $$
DECLARE got text;
BEGIN
    PERFORM apply_shipment_line('SH-A', 'AMS', DATE '2024-05-10', 'WASH-6', 60);
    PERFORM apply_shipment_line('SH-B', 'AMS', DATE '2024-05-14', 'WASH-6', 15);
    PERFORM apply_shipment_line('SH-C', 'LIS', DATE '2024-05-12', 'WASH-6', 5);

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', warehouse_code, sku, on_hand, last_receipt_on) AS line
          FROM inventory ORDER BY warehouse_code, sku) t;
    IF got <> 'AMS|WASH-6|75|2024-05-14
LIS|WASH-6|5|2024-05-12' THEN
        RAISE EXCEPTION E'two shipments into one warehouse gave\n%', got;
    END IF;
END $$;

DO $$
DECLARE d date;
BEGIN
    -- A late-arriving older shipment must not drag last_receipt_on backwards.
    PERFORM apply_shipment_line('SH-D', 'AMS', DATE '2024-04-01', 'WASH-6', 10);
    SELECT last_receipt_on INTO d FROM inventory WHERE warehouse_code = 'AMS' AND sku = 'WASH-6';
    IF d <> DATE '2024-05-14' THEN
        RAISE EXCEPTION 'last_receipt_on moved back to %, expected 2024-05-14', d;
    END IF;
END $$;

DO $$
DECLARE n integer;
BEGIN
    -- Replaying a shipment that only ever had one line is still a no-op.
    PERFORM apply_shipment_line('SH-C', 'LIS', DATE '2024-05-12', 'WASH-6', 5);
    PERFORM apply_shipment_line('SH-C', 'LIS', DATE '2024-05-12', 'WASH-6', 5);
    SELECT on_hand INTO n FROM inventory WHERE warehouse_code = 'LIS' AND sku = 'WASH-6';
    IF n <> 5 THEN RAISE EXCEPTION 'LIS/WASH-6 on_hand was %, expected 5', n; END IF;

    SELECT count(*) INTO n FROM inventory;
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 inventory rows, found %', n; END IF;
END $$;

DO $$
DECLARE n integer;
BEGIN
    -- A first receipt creates the inventory row rather than failing.
    PERFORM apply_shipment_line('SH-E', 'LIS', DATE '2024-06-01', 'BOLT-6', 7);
    SELECT on_hand INTO n FROM inventory WHERE warehouse_code = 'LIS' AND sku = 'BOLT-6';
    IF n IS DISTINCT FROM 7 THEN
        RAISE EXCEPTION 'LIS/BOLT-6 on_hand was %, expected 7', coalesce(n::text, '<missing>');
    END IF;
END $$;
