-- Edge: the view refuses writes that would push the row out of it.

DO $$
DECLARE rejected boolean := false;
BEGIN
    BEGIN
        INSERT INTO catalogue (id, sku, name, price_cents) VALUES (8, 'FREE-01', 'Free sample', 0);
    EXCEPTION WHEN with_check_option_violation OR check_violation THEN rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'the catalogue accepted an insert with a price of 0';
    END IF;
END $$;

DO $$
DECLARE rejected boolean := false; price integer;
BEGIN
    BEGIN
        UPDATE catalogue SET price_cents = 0 WHERE sku = 'DESK-01';
    EXCEPTION WHEN with_check_option_violation OR check_violation THEN rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'the catalogue accepted an update that dropped the price to 0';
    END IF;
    SELECT price_cents INTO price FROM products WHERE id = 1;
    IF price <> 89900 THEN
        RAISE EXCEPTION 'the refused update still changed the stored price to %', price;
    END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Rows the catalogue cannot see are untouched by writes against it.
    SELECT count(*) INTO n FROM catalogue WHERE sku IN ('MAT-01', 'RISER-01', 'SAMPLE-1');
    IF n <> 0 THEN
        RAISE EXCEPTION 'archived or zero-priced products are visible in the catalogue';
    END IF;

    DELETE FROM catalogue WHERE sku = 'MAT-01';
    SELECT count(*) INTO n FROM products WHERE id = 4 AND archived_at = TIMESTAMP '2023-11-02 09:00:00';
    IF n <> 1 THEN
        RAISE EXCEPTION 'deleting an invisible row through the catalogue changed it anyway';
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Un-archiving in the base table brings the product back into the catalogue.
    UPDATE products SET archived_at = NULL WHERE id = 5;
    SELECT format('%s|%s', sku, price_cents) INTO got FROM catalogue WHERE id = 5;
    IF got IS DISTINCT FROM 'RISER-01|2900' THEN
        RAISE EXCEPTION 'an un-archived product came back as %', coalesce(got, '<missing>');
    END IF;
END $$;
