-- Tenant isolation. Write the row-level security setup here.
-- This file is applied immediately after schema.sql.

-- The tenant of the current session, or NULL when nothing has been set.
-- NULL never equals a tenant_id, so an unset session sees nothing.
CREATE FUNCTION current_tenant_id() RETURNS integer
LANGUAGE sql STABLE AS $$
    SELECT nullif(current_setting('app.tenant_id', true), '')::integer;
$$;

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents FORCE ROW LEVEL SECURITY;

CREATE POLICY documents_tenant_isolation ON documents
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());

ALTER TABLE document_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_events FORCE ROW LEVEL SECURITY;

CREATE POLICY document_events_tenant_isolation ON document_events
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());
