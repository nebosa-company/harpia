-- 002: every order carries a status from here on.
--
-- Intent, as written on the ticket:
--   * orders that had already been paid for become 'shipped';
--   * every other existing order becomes 'placed';
--   * the column is mandatory, and an order created without one is 'placed';
--   * only 'placed', 'shipped' and 'cancelled' are ever allowed.

ALTER TABLE orders ADD COLUMN status text NOT NULL;

ALTER TABLE orders
    ADD CONSTRAINT orders_status_known CHECK (status IN ('placed', 'shipped', 'cancelled'));
