-- Event store schema and seed data. Payload shape varies by producer, so it
-- is kept as JSONB rather than spread across columns.

CREATE TABLE events (
    id          bigint PRIMARY KEY,
    occurred_at timestamp NOT NULL,
    payload     jsonb NOT NULL
);

INSERT INTO events (id, occurred_at, payload)
SELECT g,
       TIMESTAMP '2024-01-01 00:00:00' + (g || ' seconds')::interval,
       jsonb_build_object(
           'type',   CASE WHEN g % 47 = 0 THEN 'checkout'
                          WHEN g % 17 = 0 THEN 'add_to_cart'
                          ELSE 'view' END,
           'tenant', 'tenant-' || (g % 4),
           'cents',  g,
           'tags',   CASE WHEN g % 47 = 0 THEN '["paid", "eu"]'::jsonb
                          WHEN g % 17 = 0 THEN '["cart"]'::jsonb
                          ELSE '["browse"]'::jsonb END)
FROM generate_series(1, 40000) g;
