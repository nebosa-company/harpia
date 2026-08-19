-- Job queue schema and seed data. The table is mostly history: of the 60000
-- rows only a few hundred are still waiting to run.

CREATE TABLE jobs (
    id        bigint PRIMARY KEY,
    queue     text NOT NULL,
    state     text NOT NULL CHECK (state IN ('pending', 'running', 'done', 'failed')),
    assignee  text,
    run_after timestamp NOT NULL,
    payload   text NOT NULL
);

INSERT INTO jobs (id, queue, state, assignee, run_after, payload)
SELECT g,
       'queue-' || (g % 5),
       CASE WHEN g % 199 = 0 THEN 'pending'
            WHEN g % 197 = 0 THEN 'running'
            WHEN g % 97  = 0 THEN 'failed'
            ELSE 'done' END,
       CASE WHEN g % 3 = 0 THEN 'Ada Lovelace'
            WHEN g % 3 = 1 THEN 'BOWEN OKAFOR'
            ELSE 'cyrus mehta' END,
       TIMESTAMP '2024-01-01 00:00:00' + (g || ' minutes')::interval,
       repeat('x', 40)
FROM generate_series(1, 60000) g;
