-- Queue indexes. Create them here.
-- This file is applied immediately after schema.sql.

-- The claim path only ever looks at pending rows, so the index only holds
-- those: a few hundred entries instead of sixty thousand.
CREATE INDEX jobs_pending_claim
    ON jobs (queue, run_after)
    WHERE state = 'pending';

-- The lookup folds case, so the index has to store the folded value.
CREATE INDEX jobs_assignee_folded
    ON jobs (lower(assignee));
