-- Shipment loader. Define apply_shipment_line here.
-- This file is applied immediately after schema.sql.

CREATE FUNCTION apply_shipment_line(
    p_shipment_id    text,
    p_warehouse_code text,
    p_received_on    date,
    p_sku            text,
    p_quantity       integer
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    previous integer;
BEGIN
    INSERT INTO shipments (id, warehouse_code, received_on)
        VALUES (p_shipment_id, p_warehouse_code, p_received_on)
    ON CONFLICT (id) DO UPDATE
        SET warehouse_code = EXCLUDED.warehouse_code,
            received_on    = EXCLUDED.received_on;

    SELECT quantity INTO previous
    FROM shipment_lines
    WHERE shipment_id = p_shipment_id AND sku = p_sku;

    previous := coalesce(previous, 0);

    INSERT INTO shipment_lines (shipment_id, sku, quantity)
        VALUES (p_shipment_id, p_sku, p_quantity)
    ON CONFLICT (shipment_id, sku) DO UPDATE
        SET quantity = EXCLUDED.quantity;

    INSERT INTO inventory (warehouse_code, sku, on_hand, last_receipt_on)
        VALUES (p_warehouse_code, p_sku, p_quantity - previous, p_received_on)
    ON CONFLICT (warehouse_code, sku) DO UPDATE
        SET on_hand         = inventory.on_hand + (p_quantity - previous),
            last_receipt_on = greatest(inventory.last_receipt_on, EXCLUDED.last_receipt_on);
END;
$$;
