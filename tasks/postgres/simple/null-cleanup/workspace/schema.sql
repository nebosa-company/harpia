-- Landing table for partner contact exports, exactly as delivered.

CREATE TABLE raw_contacts (
    id        integer PRIMARY KEY,
    full_name text,
    email     text,
    phone     text,
    company   text,
    country   text
);

INSERT INTO raw_contacts (id, full_name, email, phone, company, country) VALUES
    ( 1, '  Rosa Klein ', ' ROSA@Example.COM ',   '+31 (0)20 555 1234', 'Klein BV',        'nl'),
    ( 2, 'N/A',           'imre@example.org',     'n/a',                'Imre Ltd',        'UK'),
    ( 3, '',              '',                     '020-7946-0000',      '  Ghost Works ',  ' uk '),
    ( 4, NULL,            'NULL',                 '  ',                 NULL,              'de'),
    ( 5, 'Nadia Farouk',  ' -',                   '555-12',             '-',               'FR'),
    ( 6, 'none',          'ODD@Example.com',      'none',               'none',            'none'),
    ( 7, 'Quinn Doyle',   NULL,                   '00353 1 234 5678',   NULL,              'ie'),
    ( 8, '   ',           '   ',                  '+1 (415) 555-0000',  'Bay Widgets',     'us'),
    ( 9, 'Tomas Vidal',   'TOMAS@EXAMPLE.NET ',   'n/a',                'Vidal SA',        'ES'),
    (10, 'na',            'na',                   'na',                 'na',              'na'),
    (11, 'Umi Sato',      'umi@example.jp',       '81-3-1234-5678',     NULL,              'jp'),
    (12, NULL,            NULL,                   '999 8888',           'Fallback Co',     NULL),
    (13, 'Vera Popa',     'vera@example.ro',      '+40 21 000',         'Popa SRL',        'ro'),
    (14, 'Wes Grant',     '  ',                   '(0)11 22 33 4',      'null',            'UK');
