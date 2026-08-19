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

CREATE UNIQUE INDEX customers_email_key ON customers (lower(email));
