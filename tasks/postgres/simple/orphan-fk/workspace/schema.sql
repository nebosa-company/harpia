-- Ticket store schema. seed.sql is applied straight after this file.

CREATE TABLE users (
    id     integer PRIMARY KEY,
    handle text NOT NULL UNIQUE
);

CREATE TABLE tickets (
    id        integer PRIMARY KEY,
    title     text NOT NULL,
    opened_by integer NOT NULL REFERENCES users (id),
    status    text NOT NULL CHECK (status IN ('open', 'closed'))
);

CREATE TABLE comments (
    id        integer PRIMARY KEY,
    ticket_id integer NOT NULL,
    author_id integer NOT NULL,
    body      text NOT NULL
);

CREATE TABLE attachments (
    id         integer PRIMARY KEY,
    comment_id integer NOT NULL,
    filename   text NOT NULL
);
