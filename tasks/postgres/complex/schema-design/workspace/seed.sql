-- Opening data for the two branches. Applied straight after schema.sql;
-- every row here is legal under the requirements.

INSERT INTO branches (id, code, name) VALUES
    (1, 'CEN', 'Central'),
    (2, 'RIV', 'Riverside');

INSERT INTO members (id, membership_no, full_name, joined_on, status) VALUES
    (1, 'M-0001', 'Rosa Klein',    DATE '2021-03-04', 'active'),
    (2, 'M-0002', 'Imre Bako',     DATE '2022-07-19', 'active'),
    (3, 'M-0003', 'Nadia Farouk',  DATE '2023-01-30', 'suspended'),
    (4, 'M-0004', 'Quinn Doyle',   DATE '2023-11-11', 'active'),
    (5, 'M-0005', 'Tomas Vidal',   DATE '2020-05-05', 'closed');

INSERT INTO titles (id, isbn, title, author, published_year) VALUES
    (1, '9780000000001', 'The Long Field',   'A. Mensah',  2019),
    (2, '9780000000002', 'Salt and Circuit', 'B. Ivanova', 2021),
    (3, '9780000000003', 'Quiet Machines',   'C. Ferreira', 2015),
    (4, '9780000000004', 'The Ninth Gate House', 'D. Oyelaran', 1998);

INSERT INTO copies (id, title_id, branch_id, barcode, condition) VALUES
    ( 1, 1, 1, '10000001', 'good'),
    ( 2, 1, 1, '10000002', 'fair'),
    ( 3, 1, 2, '10000003', 'good'),
    ( 4, 2, 1, '10000004', 'good'),
    ( 5, 2, 2, '10000005', 'poor'),
    ( 6, 3, 1, '10000006', 'good'),
    ( 7, 3, 1, '10000007', 'withdrawn'),
    ( 8, 4, 2, '10000008', 'good'),
    ( 9, 4, 2, '10000009', 'good'),
    (10, 4, 2, '10000010', 'withdrawn');

INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on, returned_on) VALUES
    (1, 1, 1, DATE '2024-04-01', DATE '2024-04-22', DATE '2024-04-15'),
    (2, 1, 2, DATE '2024-05-02', DATE '2024-05-23', NULL),
    (3, 3, 1, DATE '2024-04-10', DATE '2024-05-01', NULL),
    (4, 4, 4, DATE '2024-05-06', DATE '2024-05-27', NULL),
    (5, 6, 2, DATE '2024-03-01', DATE '2024-03-22', DATE '2024-03-20'),
    (6, 8, 4, DATE '2024-02-01', DATE '2024-02-22', DATE '2024-02-21'),
    (7, 9, 1, DATE '2024-05-20', DATE '2024-06-10', NULL);

INSERT INTO holds (id, title_id, member_id, placed_on, released_on) VALUES
    (1, 1, 4, DATE '2024-05-03', NULL),
    (2, 2, 1, DATE '2024-05-07', NULL),
    (3, 1, 2, DATE '2024-03-01', DATE '2024-03-09'),
    (4, 1, 2, DATE '2024-05-11', NULL);
