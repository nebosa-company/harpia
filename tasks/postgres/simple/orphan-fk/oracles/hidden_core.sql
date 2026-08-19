-- Core: the seed still loads, and nothing may reference a row that is not there.

DO $$
DECLARE n bigint;
BEGIN
    SELECT count(*) INTO n FROM users;
    IF n <> 4 THEN RAISE EXCEPTION 'expected 4 seeded users, found %', n; END IF;
    SELECT count(*) INTO n FROM tickets;
    IF n <> 3 THEN RAISE EXCEPTION 'expected 3 seeded tickets, found %', n; END IF;
    SELECT count(*) INTO n FROM comments;
    IF n <> 4 THEN RAISE EXCEPTION 'expected 4 seeded comments, found %', n; END IF;
    SELECT count(*) INTO n FROM attachments;
    IF n <> 3 THEN RAISE EXCEPTION 'expected 3 seeded attachments, found %', n; END IF;
END $$;

DO $$
DECLARE rejected boolean := false;
BEGIN
    BEGIN
        INSERT INTO comments (id, ticket_id, author_id, body)
            VALUES (900, 4242, 1, 'comment on a ticket that is not there');
    EXCEPTION WHEN foreign_key_violation THEN rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'a comment naming a ticket that does not exist was accepted';
    END IF;
END $$;

DO $$
DECLARE rejected boolean := false;
BEGIN
    BEGIN
        INSERT INTO comments (id, ticket_id, author_id, body)
            VALUES (901, 1, 4242, 'comment by a user that is not there');
    EXCEPTION WHEN foreign_key_violation THEN rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'a comment naming an author that does not exist was accepted';
    END IF;
END $$;

DO $$
DECLARE rejected boolean := false;
BEGIN
    BEGIN
        INSERT INTO attachments (id, comment_id, filename) VALUES (900, 4242, 'ghost.png');
    EXCEPTION WHEN foreign_key_violation THEN rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'an attachment naming a comment that does not exist was accepted';
    END IF;
END $$;
