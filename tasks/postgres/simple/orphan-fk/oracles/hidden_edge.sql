-- Edge: what deletion does on each side of the relationships.

DO $$
DECLARE n bigint;
BEGIN
    DELETE FROM tickets WHERE id = 1;

    SELECT count(*) INTO n FROM comments WHERE ticket_id = 1;
    IF n <> 0 THEN RAISE EXCEPTION 'deleting ticket 1 left % comment(s) behind', n; END IF;

    SELECT count(*) INTO n FROM attachments WHERE comment_id IN (1, 2);
    IF n <> 0 THEN RAISE EXCEPTION 'deleting ticket 1 left % attachment(s) behind', n; END IF;

    SELECT count(*) INTO n FROM comments;
    IF n <> 2 THEN RAISE EXCEPTION 'expected 2 surviving comments, found %', n; END IF;

    SELECT count(*) INTO n FROM attachments;
    IF n <> 1 THEN RAISE EXCEPTION 'expected 1 surviving attachment, found %', n; END IF;
END $$;

DO $$
DECLARE rejected boolean := false;
BEGIN
    BEGIN
        DELETE FROM users WHERE id = 3;
    EXCEPTION WHEN foreign_key_violation THEN rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'a user who still has comments was deleted';
    END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    DELETE FROM users WHERE id = 4;
    SELECT count(*) INTO n FROM users WHERE id = 4;
    IF n <> 0 THEN
        RAISE EXCEPTION 'a user with no tickets and no comments should still be deletable';
    END IF;
END $$;
