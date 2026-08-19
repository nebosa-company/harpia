-- Contact normalisation. Define the clean_contacts view here.
-- This file is applied immediately after schema.sql.

CREATE FUNCTION blank_to_null(v text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN v IS NULL THEN NULL
        WHEN lower(btrim(v)) IN ('', 'n/a', 'na', 'null', 'none', '-') THEN NULL
        ELSE btrim(v)
    END;
$$;

CREATE VIEW clean_contacts AS
SELECT s.id,
       coalesce(s.name, s.company, s.email, 'unknown') AS display_name,
       s.email,
       s.phone_digits,
       s.country
FROM (
    SELECT c.id,
           blank_to_null(c.full_name)         AS name,
           blank_to_null(c.company)           AS company,
           lower(blank_to_null(c.email))      AS email,
           CASE
               WHEN upper(blank_to_null(c.country)) = 'UK' THEN 'GB'
               ELSE upper(blank_to_null(c.country))
           END                                AS country,
           CASE
               WHEN length(regexp_replace(coalesce(blank_to_null(c.phone), ''),
                                          '[^0-9]', '', 'g')) >= 7
               THEN regexp_replace(coalesce(blank_to_null(c.phone), ''), '[^0-9]', '', 'g')
           END                                AS phone_digits
    FROM raw_contacts c
) s
WHERE s.email IS NOT NULL OR s.phone_digits IS NOT NULL;
