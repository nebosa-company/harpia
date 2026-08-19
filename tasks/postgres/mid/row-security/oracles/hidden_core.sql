-- Core: an application session sees and writes only its own tenant's rows.
-- The checks run as a throwaway role, because a superuser is never subject to
-- row-level security. Creating a role is transactional, so a failure here
-- rolls the role back with everything else.

DO $$
DECLARE r name := (current_database() || '_app')::name;
        n bigint;
        got text;
        blocked boolean;
BEGIN
    EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON documents, document_events TO %I', r);
    EXECUTE format('SET LOCAL ROLE %I', r);

    -- Tenant 1
    PERFORM set_config('app.tenant_id', '1', true);
    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT id::text AS line FROM documents ORDER BY id) t;
    IF got <> '1,2' THEN RAISE EXCEPTION 'tenant 1 saw documents %, expected 1,2', got; END IF;

    -- Tenant 2
    PERFORM set_config('app.tenant_id', '2', true);
    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT id::text AS line FROM documents ORDER BY id) t;
    IF got <> '3,4,5' THEN RAISE EXCEPTION 'tenant 2 saw documents %, expected 3,4,5', got; END IF;

    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT id::text AS line FROM document_events ORDER BY id) t;
    IF got <> '3,4' THEN RAISE EXCEPTION 'tenant 2 saw events %, expected 3,4', got; END IF;

    -- Writing into someone else's tenant is refused.
    blocked := false;
    BEGIN
        INSERT INTO documents (id, tenant_id, title, body)
            VALUES (900, 1, 'stolen', 'x');
    EXCEPTION WHEN insufficient_privilege THEN blocked := true;
    END;
    IF NOT blocked THEN
        RAISE EXCEPTION 'tenant 2 inserted a document into tenant 1';
    END IF;

    -- Writing into its own tenant works.
    INSERT INTO documents (id, tenant_id, title, body) VALUES (901, 2, 'mine', 'y');
    SELECT count(*) INTO n FROM documents WHERE id = 901;
    IF n <> 1 THEN RAISE EXCEPTION 'tenant 2 could not insert into its own tenant'; END IF;

    -- Moving a row to another tenant is refused.
    blocked := false;
    BEGIN
        UPDATE documents SET tenant_id = 3 WHERE id = 901;
    EXCEPTION WHEN insufficient_privilege THEN blocked := true;
    END;
    IF NOT blocked THEN
        RAISE EXCEPTION 'a document was moved out of its tenant';
    END IF;

    -- Another tenant's rows cannot be updated or deleted, not even by id.
    UPDATE documents SET title = 'tampered' WHERE id = 1;
    DELETE FROM documents WHERE id = 1;

    RESET ROLE;

    SELECT count(*) INTO n FROM documents WHERE id = 1 AND title = 'Q1 plan';
    IF n <> 1 THEN
        RAISE EXCEPTION 'a document belonging to another tenant was changed or removed';
    END IF;

    EXECUTE format('REVOKE ALL ON documents, document_events FROM %I', r);
    EXECUTE format('DROP ROLE %I', r);
END $$;
