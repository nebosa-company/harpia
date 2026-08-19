-- Sample subscriptions. Every row here already satisfies the billing rules.

INSERT INTO plans (code, monthly_cents) VALUES
    ('starter', 0),
    ('team',    9900),
    ('scale',   49900);

INSERT INTO subscriptions
    (id, account_ref, plan_code, seats, started_on, ended_on, status, discount_pct) VALUES
    (1, 'acct-1001', 'team',    12, DATE '2023-06-01', NULL,               'active',    0.00),
    (2, 'acct-1002', 'starter',  1, DATE '2023-07-14', NULL,               'trialing',  0.00),
    (3, 'acct-1003', 'scale',  500, DATE '2022-01-01', DATE '2023-12-31',  'cancelled', 25.00),
    (4, 'acct-1003', 'scale',  240, DATE '2024-01-01', NULL,               'active',   10.50),
    (5, 'acct-1004', 'team',     3, DATE '2024-02-02', DATE '2024-02-02',  'cancelled', 0.00),
    (6, 'acct-1005', 'team',     8, DATE '2024-03-01', NULL,               'paused',  100.00);
