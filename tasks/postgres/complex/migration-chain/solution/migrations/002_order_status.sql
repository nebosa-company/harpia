-- 002: every order carries a status from here on.
--
-- Intent, as written on the ticket:
--   * orders that had already been paid for become 'shipped';
--   * every other existing order becomes 'placed';
--   * the column is mandatory, and an order created without one is 'placed';
--   * only 'placed', 'shipped' and 'cancelled' are ever allowed.

-- The table already has rows, so the column arrives empty, gets filled, and
-- only then becomes mandatory.
ALTER TABLE orders ADD COLUMN status text;

UPDATE orders o
   SET status = CASE
                    WHEN EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.id)
                        THEN 'shipped'
                    ELSE 'placed'
                END;

ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'placed';
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;

ALTER TABLE orders
    ADD CONSTRAINT orders_status_known CHECK (status IN ('placed', 'shipped', 'cancelled'));
