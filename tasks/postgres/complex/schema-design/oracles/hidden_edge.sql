-- Edge: every rule in the requirements, probed from both sides.

CREATE FUNCTION _hidden_must_reject(stmt text, what text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION
        WHEN undefined_table OR undefined_column OR undefined_function OR syntax_error THEN
            RAISE;
        WHEN OTHERS THEN
            RETURN;
    END;
    RAISE EXCEPTION 'the database accepted %', what;
END $$;

DO $$
BEGIN
    -- References must be real.
    PERFORM _hidden_must_reject(
        'INSERT INTO copies (id, title_id, branch_id, barcode, condition) '
        'VALUES (900, 999, 1, ''90000001'', ''good'')',
        'a copy of a title that does not exist');
    PERFORM _hidden_must_reject(
        'INSERT INTO copies (id, title_id, branch_id, barcode, condition) '
        'VALUES (901, 1, 999, ''90000002'', ''good'')',
        'a copy held by a branch that does not exist');
    PERFORM _hidden_must_reject(
        'INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on) '
        'VALUES (900, 999, 1, DATE ''2024-06-01'', DATE ''2024-06-22'')',
        'a loan of a copy that does not exist');
    PERFORM _hidden_must_reject(
        'INSERT INTO holds (id, title_id, member_id, placed_on) '
        'VALUES (900, 1, 999, DATE ''2024-06-01'')',
        'a hold for a member that does not exist');

    -- Value rules.
    PERFORM _hidden_must_reject(
        'INSERT INTO copies (id, title_id, branch_id, barcode, condition) '
        'VALUES (902, 1, 1, ''1234567'', ''good'')',
        'a barcode of seven digits');
    PERFORM _hidden_must_reject(
        'INSERT INTO copies (id, title_id, branch_id, barcode, condition) '
        'VALUES (903, 1, 1, ''1234567a'', ''good'')',
        'a barcode containing a letter');
    PERFORM _hidden_must_reject(
        'INSERT INTO copies (id, title_id, branch_id, barcode, condition) '
        'VALUES (904, 1, 1, ''90000003'', ''shabby'')',
        'a copy in an unknown condition');
    PERFORM _hidden_must_reject(
        'INSERT INTO titles (id, isbn, title, author, published_year) '
        'VALUES (900, ''9990000000001'', ''Too Old'', ''X'', 1200)',
        'a title published in 1200');
    PERFORM _hidden_must_reject(
        'INSERT INTO members (id, membership_no, full_name, joined_on, status) '
        'VALUES (900, ''M-0900'', ''X'', DATE ''2024-01-01'', ''lapsed'')',
        'a member in an unknown status');

    -- Date ordering.
    PERFORM _hidden_must_reject(
        'INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on) '
        'VALUES (901, 2, 1, DATE ''2024-06-10'', DATE ''2024-06-10'')',
        'a loan due on the day it was borrowed');
    PERFORM _hidden_must_reject(
        'INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on, returned_on) '
        'VALUES (902, 2, 1, DATE ''2024-06-10'', DATE ''2024-07-01'', DATE ''2024-06-09'')',
        'a loan returned before it was borrowed');
    PERFORM _hidden_must_reject(
        'INSERT INTO holds (id, title_id, member_id, placed_on, released_on) '
        'VALUES (901, 3, 1, DATE ''2024-06-10'', DATE ''2024-06-09'')',
        'a hold released before it was placed');
END $$;

DO $$
BEGIN
    -- One open loan per copy; one open hold per member and title.
    PERFORM _hidden_must_reject(
        'INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on) '
        'VALUES (903, 3, 4, DATE ''2024-06-01'', DATE ''2024-06-22'')',
        'a second open loan on a copy that is already out');
    PERFORM _hidden_must_reject(
        'INSERT INTO holds (id, title_id, member_id, placed_on) '
        'VALUES (902, 1, 4, DATE ''2024-06-01'')',
        'a second open hold on the same title by the same member');
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- A returned copy can go straight back out, and a released hold reopens.
    UPDATE loans SET returned_on = DATE '2024-06-01' WHERE id = 3;
    INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on)
        VALUES (910, 3, 4, DATE '2024-06-02', DATE '2024-06-23');
    SELECT count(*) INTO n FROM loans WHERE copy_id = 3 AND returned_on IS NULL;
    IF n <> 1 THEN RAISE EXCEPTION 'copy 3 has % open loans after re-lending, expected 1', n; END IF;

    UPDATE holds SET released_on = DATE '2024-06-01' WHERE id = 1;
    INSERT INTO holds (id, title_id, member_id, placed_on)
        VALUES (910, 1, 4, DATE '2024-06-02');
    SELECT count(*) INTO n FROM holds WHERE title_id = 1 AND member_id = 4 AND released_on IS NULL;
    IF n <> 1 THEN RAISE EXCEPTION 'member 4 has % open holds on title 1, expected 1', n; END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Withdrawn copies are not lendable, and a copy that is out is not withdrawable.
    PERFORM _hidden_must_reject(
        'INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on) '
        'VALUES (920, 7, 1, DATE ''2024-06-01'', DATE ''2024-06-22'')',
        'a loan of a withdrawn copy');
    PERFORM _hidden_must_reject(
        'UPDATE copies SET condition = ''withdrawn'' WHERE id = 4',
        'withdrawing a copy that is out on loan');

    -- Withdrawing a copy that is on the shelf is fine.
    UPDATE copies SET condition = 'withdrawn' WHERE id = 6;
    SELECT count(*) INTO n FROM copies WHERE id = 6 AND condition = 'withdrawn';
    IF n <> 1 THEN RAISE EXCEPTION 'a copy on the shelf could not be withdrawn'; END IF;
END $$;

DO $$
DECLARE n bigint;
BEGIN
    -- Only active members borrow; anybody may return.
    PERFORM _hidden_must_reject(
        'INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on) '
        'VALUES (930, 2, 3, DATE ''2024-06-01'', DATE ''2024-06-22'')',
        'a loan to a suspended member');
    PERFORM _hidden_must_reject(
        'INSERT INTO loans (id, copy_id, member_id, borrowed_on, due_on) '
        'VALUES (931, 2, 5, DATE ''2024-06-01'', DATE ''2024-06-22'')',
        'a loan to a closed member');

    UPDATE members SET status = 'suspended' WHERE id = 1;
    UPDATE loans SET returned_on = DATE '2024-06-05' WHERE id = 7;
    SELECT count(*) INTO n FROM loans WHERE id = 7 AND returned_on = DATE '2024-06-05';
    IF n <> 1 THEN
        RAISE EXCEPTION 'a suspended member was prevented from returning a copy';
    END IF;
END $$;

DO $$
DECLARE got text;
BEGIN
    -- Withdrawing copy 6 empties CEN's holding of that title from the report.
    SELECT coalesce(string_agg(t.line, ','), '<no rows>') INTO got
    FROM (SELECT format('%s:%s:%s', branch_code, total_copies, available) AS line
          FROM branch_stock WHERE isbn = '9780000000003' ORDER BY branch_code) t;
    IF got <> '<no rows>' THEN
        RAISE EXCEPTION 'a title with only withdrawn copies still reports stock: %', got;
    END IF;
END $$;
