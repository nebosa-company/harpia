-- 003: one customer per e-mail address, compared without regard to case.
--
-- Intent, as written on the ticket:
--   * where the same address appears more than once, the record with the
--     lowest id is the real one and survives, keeping its own name and
--     e-mail spelling;
--   * anything belonging to the other records moves across to it, so nothing
--     is stranded;
--   * the other records are then removed;
--   * from here on the database refuses a second customer on an address that
--     is already taken, whatever the casing.

-- Move the losers' orders onto the survivor before anything is deleted,
-- otherwise 004 finds a fresh crop of orphans.
UPDATE orders o
   SET customer_id = k.id
  FROM customers c
  JOIN customers k ON lower(k.email) = lower(c.email) AND k.id < c.id
 WHERE o.customer_id = c.id
   AND k.id = (SELECT min(k2.id) FROM customers k2 WHERE lower(k2.email) = lower(c.email));

DELETE FROM customers c
 WHERE EXISTS (SELECT 1 FROM customers k
                WHERE lower(k.email) = lower(c.email) AND k.id < c.id);

CREATE UNIQUE INDEX customers_email_key ON customers (lower(email));
