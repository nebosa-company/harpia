-- Core: the cleaned contacts, exactly and in order.

DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(c.col, ', ' ORDER BY c.col) INTO missing
    FROM (VALUES ('id'), ('display_name'), ('email'), ('phone_digits'), ('country')) AS c (col)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'clean_contacts'
          AND column_name = c.col);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'clean_contacts is missing column(s): %', missing;
    END IF;
END $$;

DO $$
DECLARE got text; want text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s|%s', id, display_name, coalesce(email, '<null>'),
                        coalesce(phone_digits, '<null>'), coalesce(country, '<null>')) AS line
          FROM clean_contacts ORDER BY id) t;

    want := '1|Rosa Klein|rosa@example.com|310205551234|NL
2|Imre Ltd|imre@example.org|<null>|GB
3|Ghost Works|<null>|02079460000|GB
6|odd@example.com|odd@example.com|<null>|<null>
7|Quinn Doyle|<null>|0035312345678|IE
8|Bay Widgets|<null>|14155550000|US
9|Tomas Vidal|tomas@example.net|<null>|ES
11|Umi Sato|umi@example.jp|81312345678|JP
12|Fallback Co|<null>|9998888|<null>
13|Vera Popa|vera@example.ro|4021000|RO
14|Wes Grant|<null>|01122334|GB';

    IF got <> want THEN
        RAISE EXCEPTION E'clean_contacts does not match\n--- expected ---\n%\n--- actual ---\n%', want, got;
    END IF;
END $$;
