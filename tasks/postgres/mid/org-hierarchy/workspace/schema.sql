-- Org directory schema and seed data.
-- manager_id is NULL for the top of a tree; the directory holds several trees.

CREATE TABLE employees (
    id           integer PRIMARY KEY,
    name         text NOT NULL,
    manager_id   integer REFERENCES employees (id),
    title        text NOT NULL,
    salary_cents integer NOT NULL CHECK (salary_cents >= 0)
);

INSERT INTO employees (id, name, manager_id, title, salary_cents) VALUES
    ( 1, 'Rosalind Vega',  NULL, 'Chief executive',      2400000),
    ( 2, 'Idris Bello',       1, 'VP engineering',       1800000),
    ( 3, 'Mira Kohl',         1, 'VP operations',        1750000),
    ( 4, 'Tomasz Reik',       2, 'Director, platform',   1400000),
    ( 5, 'Nour Haddad',       2, 'Director, product',    1380000),
    ( 6, 'Paulo Serra',       4, 'Staff engineer',       1200000),
    ( 7, 'Kiri Manaia',       4, 'Senior engineer',      1050000),
    ( 8, 'Alex Turchin',      6, 'Engineer',              900000),
    ( 9, 'Devi Raman',        5, 'Product manager',       980000),
    (10, 'Sam Oyelaran',      3, 'Operations lead',       960000),
    (11, 'Wren Fisk',        10, 'Analyst',               720000),
    (12, 'Cato Iversen',   NULL, 'Contract principal',   1500000),
    (13, 'Lena Brandt',      12, 'Contract engineer',     880000);
