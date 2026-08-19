-- Event queries and their indexes. Write them here.
-- This file is applied immediately after schema.sql.

-- Containment against the whole payload.
CREATE INDEX events_payload_gin ON events USING gin (payload);

-- Key lookups inside the tags array need the array itself indexed: an index
-- on payload alone cannot serve `payload -> 'tags' ? ...`.
CREATE INDEX events_tags_gin ON events USING gin ((payload -> 'tags'));

CREATE VIEW checkout_totals AS
SELECT e.payload ->> 'tenant'              AS tenant,
       count(*)::bigint                    AS checkouts,
       sum((e.payload ->> 'cents')::bigint)::bigint AS cents
FROM events e
WHERE e.payload @> '{"type": "checkout"}'::jsonb
GROUP BY 1;

CREATE FUNCTION events_with_tag(p_tag text)
RETURNS TABLE (id bigint, occurred_at timestamp)
LANGUAGE sql STABLE AS $$
    SELECT e.id, e.occurred_at
    FROM events e
    WHERE e.payload -> 'tags' ? p_tag
    ORDER BY e.id;
$$;
