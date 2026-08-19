-- Sample content for local work. Every row here is internally consistent.

INSERT INTO users (id, handle) VALUES
    (1, 'rosa'), (2, 'imre'), (3, 'nadia'), (4, 'quiet-account');

INSERT INTO tickets (id, title, opened_by, status) VALUES
    (1, 'Export finishes with no rows',      1, 'open'),
    (2, 'Timezone drift on the audit trail', 2, 'open'),
    (3, 'Typo on the settings page',         3, 'closed');

INSERT INTO comments (id, ticket_id, author_id, body) VALUES
    (1, 1, 2, 'Reproduced on staging.'),
    (2, 1, 1, 'Only when the filter is empty.'),
    (3, 2, 3, 'The offset is applied twice.'),
    (4, 3, 1, 'Fixed in the copy deck.');

INSERT INTO attachments (id, comment_id, filename) VALUES
    (1, 1, 'staging-export.csv'),
    (2, 1, 'console.log'),
    (3, 3, 'trace.txt');
