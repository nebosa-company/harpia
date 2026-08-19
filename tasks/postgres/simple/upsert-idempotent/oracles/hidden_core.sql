-- Core: a shipment applies once, replays for free, and corrects by the delta.

DO $$
DECLARE got text;
BEGIN
    PERFORM apply_shipment_line('SH-1', 'AMS', DATE '2024-05-02', 'BOLT-6', 100);
    PERFORM apply_shipment_line('SH-1', 'AMS', DATE '2024-05-02', 'NUT-6',  40);

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', warehouse_code, sku, on_hand, last_receipt_on) AS line
          FROM inventory ORDER BY warehouse_code, sku) t;
    IF got <> 'AMS|BOLT-6|100|2024-05-02
AMS|NUT-6|40|2024-05-02' THEN
        RAISE EXCEPTION E'after the first delivery inventory was\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text; n bigint;
BEGIN
    -- The supplier's transfer job retried: the identical file arrives again.
    PERFORM apply_shipment_line('SH-1', 'AMS', DATE '2024-05-02', 'BOLT-6', 100);
    PERFORM apply_shipment_line('SH-1', 'AMS', DATE '2024-05-02', 'NUT-6',  40);

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', warehouse_code, sku, on_hand, last_receipt_on) AS line
          FROM inventory ORDER BY warehouse_code, sku) t;
    IF got <> 'AMS|BOLT-6|100|2024-05-02
AMS|NUT-6|40|2024-05-02' THEN
        RAISE EXCEPTION E'replaying the same shipment changed inventory to\n%', got;
    END IF;

    SELECT count(*) INTO n FROM shipment_lines WHERE shipment_id = 'SH-1';
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 shipment_lines for SH-1, found %', n; END IF;
    SELECT count(*) INTO n FROM shipments;
    IF n <> 1 THEN RAISE EXCEPTION 'expected 1 shipment row, found %', n; END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Corrected file: 100 bolts was really 130, and the nuts line drops to 25.
    PERFORM apply_shipment_line('SH-1', 'AMS', DATE '2024-05-02', 'BOLT-6', 130);
    PERFORM apply_shipment_line('SH-1', 'AMS', DATE '2024-05-02', 'NUT-6',  25);

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s', warehouse_code, sku, on_hand) AS line
          FROM inventory ORDER BY warehouse_code, sku) t;
    IF got <> 'AMS|BOLT-6|130
AMS|NUT-6|25' THEN
        RAISE EXCEPTION E'after the correction inventory was\n%', got;
    END IF;
END $$;
