-- Storefront access layer. Define the catalogue view here.
-- This file is applied immediately after schema.sql.

CREATE VIEW catalogue AS
SELECT id, sku, name, price_cents
FROM products
WHERE archived_at IS NULL
  AND price_cents > 0
WITH CASCADED CHECK OPTION;

CREATE FUNCTION catalogue_archive() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE products
       SET archived_at = localtimestamp
     WHERE id = OLD.id;
    RETURN OLD;
END;
$$;

CREATE TRIGGER catalogue_delete_archives
    INSTEAD OF DELETE ON catalogue
    FOR EACH ROW EXECUTE FUNCTION catalogue_archive();
