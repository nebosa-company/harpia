-- Core: what the catalogue shows, and what writing through it does.

DO $$
DECLARE got text;
BEGIN
    SELECT coalesce(string_agg(t.line, E'\n'), '<no rows>') INTO got
    FROM (SELECT format('%s|%s|%s|%s', id, sku, name, price_cents) AS line
          FROM catalogue ORDER BY id) t;
    IF got <> '1|DESK-01|Standing desk|89900
2|CHAIR-01|Task chair|34900
3|LAMP-01|Desk lamp|4900' THEN
        RAISE EXCEPTION E'catalogue shows\n%', got;
    END IF;
END $$;

DO $$
DECLARE got text; live boolean;
BEGIN
    INSERT INTO catalogue (id, sku, name, price_cents) VALUES (7, 'TRAY-01', 'Cable tray', 1900);
    SELECT format('%s|%s', name, price_cents), archived_at IS NULL INTO got, live
    FROM products WHERE id = 7;
    IF got IS DISTINCT FROM 'Cable tray|1900' THEN
        RAISE EXCEPTION 'inserting through the catalogue stored %', coalesce(got, '<nothing>');
    END IF;
    IF NOT live THEN
        RAISE EXCEPTION 'a product inserted through the catalogue was created already archived';
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    UPDATE catalogue SET name = 'Desk lamp (warm)', price_cents = 5400 WHERE sku = 'LAMP-01';
    SELECT format('%s|%s', name, price_cents) INTO got FROM products WHERE id = 3;
    IF got IS DISTINCT FROM 'Desk lamp (warm)|5400' THEN
        RAISE EXCEPTION 'updating through the catalogue stored %', coalesce(got, '<nothing>');
    END IF;
END $$;

DO $$
DECLARE n bigint; archived boolean;
BEGIN
    SELECT count(*) INTO n FROM products;
    IF n <> 7 THEN RAISE EXCEPTION 'expected 7 products before the delete, found %', n; END IF;

    DELETE FROM catalogue WHERE sku = 'CHAIR-01';

    SELECT count(*) INTO n FROM products;
    IF n <> 7 THEN
        RAISE EXCEPTION 'deleting through the catalogue removed the underlying row (% left)', n;
    END IF;
    SELECT archived_at IS NOT NULL INTO archived FROM products WHERE id = 2;
    IF NOT archived THEN
        RAISE EXCEPTION 'deleting through the catalogue did not archive the product';
    END IF;
    SELECT count(*) INTO n FROM catalogue WHERE sku = 'CHAIR-01';
    IF n <> 0 THEN RAISE EXCEPTION 'the archived product is still in the catalogue'; END IF;
END $$;
