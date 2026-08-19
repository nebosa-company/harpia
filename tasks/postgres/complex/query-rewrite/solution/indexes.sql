-- Any indexes the rewritten views need. Applied immediately after queries.sql.

-- march_orders now filters on placed_at directly, so this is usable.
CREATE INDEX orders_placed_at_idx ON orders (placed_at);
