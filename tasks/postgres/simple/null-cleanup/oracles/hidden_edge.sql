-- Edge: the placeholders, the phone-length boundary, and the last-resort name.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM clean_contacts WHERE id IN (4, 5, 10);
    IF n <> 0 THEN
        RAISE EXCEPTION 'contacts with neither an e-mail nor a usable phone are still reported (% of them)', n;
    END IF;
    SELECT count(*) INTO n FROM clean_contacts WHERE display_name IS NULL;
    IF n <> 0 THEN RAISE EXCEPTION 'display_name is NULL on % row(s)', n; END IF;
    SELECT count(*) INTO n FROM clean_contacts
    WHERE email IS NOT NULL AND email <> lower(email);
    IF n <> 0 THEN RAISE EXCEPTION '% e-mail(s) were not lower-cased', n; END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Exactly seven digits is enough; six is not.
    INSERT INTO raw_contacts (id, full_name, email, phone, company, country) VALUES
        (100, NULL,  '  ', '12-34-567',    'N/A', '  '),
        (101, 'n/a', NULL, '(12) 34-567 ', NULL,  'uk'),
        (102, NULL,  NULL, '12 34 56',     NULL,  NULL);

    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', id, display_name,
                        coalesce(phone_digits, '<null>'), coalesce(country, '<null>')) AS line
          FROM clean_contacts WHERE id >= 100 ORDER BY id) t;

    IF got <> '100|unknown|1234567|<null>
101|unknown|1234567|GB' THEN
        RAISE EXCEPTION E'the boundary rows came out as\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Placeholder text is stripped whatever its casing or padding.
    INSERT INTO raw_contacts (id, full_name, email, phone, company, country) VALUES
        (110, '  NULL ', ' Amina@Example.COM ', ' NONE ', ' Amina GmbH ', ' Uk ');
    SELECT format('%s|%s|%s|%s', display_name, coalesce(email, '<null>'),
                  coalesce(phone_digits, '<null>'), coalesce(country, '<null>')) INTO got
    FROM clean_contacts WHERE id = 110;
    IF got IS DISTINCT FROM 'Amina GmbH|amina@example.com|<null>|GB' THEN
        RAISE EXCEPTION 'row 110 came out as %, expected Amina GmbH|amina@example.com|<null>|GB',
            coalesce(got, '<missing>');
    END IF;
END $$;
