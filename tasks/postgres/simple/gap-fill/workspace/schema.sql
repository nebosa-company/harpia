-- Signup tracking schema and seed data.

CREATE TABLE sources (
    code  text PRIMARY KEY,
    label text NOT NULL
);

CREATE TABLE signups (
    id          integer PRIMARY KEY,
    source_code text NOT NULL REFERENCES sources (code),
    created_at  timestamp NOT NULL
);

INSERT INTO sources (code, label) VALUES
    ('web',     'Website'),
    ('mobile',  'Mobile app'),
    ('partner', 'Partner referral'),
    ('kiosk',   'In-store kiosk');

INSERT INTO signups (id, source_code, created_at) VALUES
    ( 1, 'web',     TIMESTAMP '2024-02-28 09:14:00'),
    ( 2, 'web',     TIMESTAMP '2024-03-01 08:02:00'),
    ( 3, 'web',     TIMESTAMP '2024-03-01 19:40:00'),
    ( 4, 'mobile',  TIMESTAMP '2024-03-01 11:25:00'),
    ( 5, 'web',     TIMESTAMP '2024-03-02 07:55:00'),
    ( 6, 'partner', TIMESTAMP '2024-03-03 15:00:00'),
    ( 7, 'mobile',  TIMESTAMP '2024-03-05 10:10:00'),
    ( 8, 'mobile',  TIMESTAMP '2024-03-05 10:11:00'),
    ( 9, 'mobile',  TIMESTAMP '2024-03-05 23:59:00'),
    (10, 'web',     TIMESTAMP '2024-03-06 12:00:00'),
    (11, 'web',     TIMESTAMP '2024-03-08 06:30:00'),
    (12, 'partner', TIMESTAMP '2024-03-08 18:45:00'),
    (13, 'web',     TIMESTAMP '2024-03-11 09:00:00'),
    (14, 'web',     TIMESTAMP '2024-03-11 09:05:00'),
    (15, 'web',     TIMESTAMP '2024-03-11 21:30:00'),
    (16, 'mobile',  TIMESTAMP '2024-03-12 13:20:00'),
    (17, 'partner', TIMESTAMP '2024-03-14 00:00:00'),
    (18, 'web',     TIMESTAMP '2024-03-14 23:59:59'),
    (19, 'web',     TIMESTAMP '2024-03-15 08:00:00'),
    (20, 'mobile',  TIMESTAMP '2024-03-20 08:00:00');
