-- 004: the relationships stop being a convention and become real.
--
-- Intent, as written on the ticket:
--   * rows left pointing at a parent that never existed are junk the incident
--     produced, and are to be removed rather than repaired;
--   * an order must name a customer that exists;
--   * a payment must name an order that exists, and must follow that order
--     out of the database when it is deleted.

-- Clear the junk out first; payments of a discarded order go with it.
DELETE FROM payments p
 WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.id = p.order_id);

DELETE FROM orders o
 WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.id = o.customer_id);

DELETE FROM payments p
 WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.id = p.order_id);

ALTER TABLE orders
    ADD CONSTRAINT orders_customer_fk FOREIGN KEY (customer_id) REFERENCES customers (id);

ALTER TABLE payments
    ADD CONSTRAINT payments_order_fk FOREIGN KEY (order_id) REFERENCES orders (id)
        ON DELETE CASCADE;
