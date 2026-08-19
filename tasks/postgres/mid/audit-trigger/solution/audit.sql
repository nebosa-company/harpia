-- Auditing. Write the trigger function and the trigger here.
-- This file is applied immediately after schema.sql.

CREATE FUNCTION accounts_audit() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    actor text := coalesce(nullif(current_setting('app.actor', true), ''), 'system');
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO account_audit (account_id, action, old_row, new_row, changed_by, changed_at)
            VALUES (NEW.id, 'INSERT', NULL, to_jsonb(NEW), actor, now());
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW IS NOT DISTINCT FROM OLD THEN
            RETURN NEW;
        END IF;
        INSERT INTO account_audit (account_id, action, old_row, new_row, changed_by, changed_at)
            VALUES (NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), actor, now());
        RETURN NEW;
    ELSE
        INSERT INTO account_audit (account_id, action, old_row, new_row, changed_by, changed_at)
            VALUES (OLD.id, 'DELETE', to_jsonb(OLD), NULL, actor, now());
        RETURN OLD;
    END IF;
END;
$$;

CREATE TRIGGER accounts_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON accounts
    FOR EACH ROW EXECUTE FUNCTION accounts_audit();
