-- Edge: failing closed when no tenant is set, and the owner being bound too.

DO $$
DECLARE n bigint;
BEGIN
    FOR n IN
        SELECT count(*) FROM pg_class
        WHERE relname IN ('documents', 'document_events')
          AND relnamespace = 'public'::regnamespace
          AND relrowsecurity
    LOOP
        IF n <> 2 THEN
            RAISE EXCEPTION 'row-level security is enabled on % of the two tenant tables', n;
        END IF;
    END LOOP;

    SELECT count(*) INTO n FROM pg_class
    WHERE relname IN ('documents', 'document_events')
      AND relnamespace = 'public'::regnamespace
      AND relforcerowsecurity;
    IF n <> 2 THEN
        RAISE EXCEPTION 'only % of the two tenant tables force the policies on their owner', n;
    END IF;
END $$;

DO $$
DECLARE r name := (current_database() || '_edge')::name;
        n bigint;
        blocked boolean;
BEGIN
    EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON documents, document_events TO %I', r);
    EXECUTE format('SET LOCAL ROLE %I', r);

    -- Nothing set at all: no rows, and no writes.
    PERFORM set_config('app.tenant_id', '', true);
    SELECT count(*) INTO n FROM documents;
    IF n <> 0 THEN
        RAISE EXCEPTION 'a session with no tenant set saw % document(s)', n;
    END IF;
    SELECT count(*) INTO n FROM document_events;
    IF n <> 0 THEN
        RAISE EXCEPTION 'a session with no tenant set saw % event(s)', n;
    END IF;

    blocked := false;
    BEGIN
        INSERT INTO documents (id, tenant_id, title, body) VALUES (910, 1, 'anon', 'x');
    EXCEPTION WHEN insufficient_privilege THEN blocked := true;
    END;
    IF NOT blocked THEN
        RAISE EXCEPTION 'a session with no tenant set inserted a document';
    END IF;

    -- A tenant that owns nothing sees nothing rather than everything.
    PERFORM set_config('app.tenant_id', '99', true);
    SELECT count(*) INTO n FROM documents;
    IF n <> 0 THEN
        RAISE EXCEPTION 'an unknown tenant saw % document(s)', n;
    END IF;

    -- Events are scoped by their own tenant column.
    PERFORM set_config('app.tenant_id', '3', true);
    SELECT count(*) INTO n FROM document_events;
    IF n <> 1 THEN
        RAISE EXCEPTION 'tenant 3 saw % event(s), expected 1', n;
    END IF;

    INSERT INTO document_events (id, tenant_id, document_id, kind) VALUES (910, 3, 6, 'viewed');
    SELECT count(*) INTO n FROM document_events;
    IF n <> 2 THEN
        RAISE EXCEPTION 'tenant 3 saw % event(s) after adding one, expected 2', n;
    END IF;

    RESET ROLE;
    EXECUTE format('REVOKE ALL ON documents, document_events FROM %I', r);
    EXECUTE format('DROP ROLE %I', r);
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Nothing was lost along the way.
    SELECT count(*) INTO n FROM documents;
    IF n < 6 THEN RAISE EXCEPTION 'only % documents remain, expected at least 6', n; END IF;
END $$;
