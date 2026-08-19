-- Reference schema and seed data for the accounts database.

CREATE TABLE accounts (
    id           integer PRIMARY KEY,
    name         text NOT NULL,
    signed_up_on date NOT NULL,
    plan         text NOT NULL CHECK (plan IN ('free', 'team', 'enterprise'))
);

CREATE TABLE payments (
    id           integer PRIMARY KEY,
    account_id   integer NOT NULL REFERENCES accounts (id),
    paid_on      date NOT NULL,
    amount_cents integer NOT NULL CHECK (amount_cents > 0)
);

INSERT INTO accounts (id, name, signed_up_on, plan) VALUES
    ( 1, 'Alder',    DATE '2023-01-04', 'team'),
    ( 2, 'Birch',    DATE '2023-01-17', 'free'),
    ( 3, 'Cedar',    DATE '2023-01-28', 'enterprise'),
    ( 4, 'Damson',   DATE '2023-01-31', 'free'),
    ( 5, 'Elm',      DATE '2023-02-02', 'team'),
    ( 6, 'Fir',      DATE '2023-02-20', 'free'),
    ( 7, 'Gorse',    DATE '2023-03-05', 'team'),
    ( 8, 'Hazel',    DATE '2023-03-09', 'free'),
    ( 9, 'Ivy',      DATE '2023-03-21', 'free'),
    (10, 'Juniper',  DATE '2023-03-30', 'enterprise'),
    (11, 'Kauri',    DATE '2023-04-11', 'free'),
    (12, 'Larch',    DATE '2023-04-12', 'free'),
    (13, 'Maple',    DATE '2023-04-27', 'free');

INSERT INTO payments (id, account_id, paid_on, amount_cents) VALUES
    ( 1,  1, DATE '2023-02-01',  9900),
    ( 2,  1, DATE '2023-03-01',  9900),
    ( 3,  3, DATE '2023-02-01', 49900),
    ( 4,  3, DATE '2023-03-01', 49900),
    ( 5,  3, DATE '2023-04-01', 49900),
    ( 6,  5, DATE '2023-03-01',  9900),
    ( 7,  7, DATE '2023-04-01',  9900),
    ( 8,  7, DATE '2023-05-01',  9900),
    ( 9, 10, DATE '2023-04-01', 49900),
    (10, 10, DATE '2023-05-01', 49900);
