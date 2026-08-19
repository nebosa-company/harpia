-- The branch library schema. Build it here, to REQUIREMENTS.md.
-- seed.sql is applied immediately after this file.

CREATE TABLE branches (
    id   integer PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL
);

CREATE TABLE members (
    id            integer PRIMARY KEY,
    membership_no text NOT NULL UNIQUE,
    full_name     text NOT NULL,
    joined_on     date NOT NULL,
    status        text NOT NULL CHECK (status IN ('active', 'suspended', 'closed'))
);

CREATE TABLE titles (
    id             integer PRIMARY KEY,
    isbn           text NOT NULL UNIQUE,
    title          text NOT NULL,
    author         text NOT NULL,
    published_year integer NOT NULL CHECK (published_year BETWEEN 1450 AND 2100)
);

CREATE TABLE copies (
    id        integer PRIMARY KEY,
    title_id  integer NOT NULL REFERENCES titles (id),
    branch_id integer NOT NULL REFERENCES branches (id),
    barcode   text NOT NULL UNIQUE CHECK (barcode ~ '^[0-9]{8}$'),
    condition text NOT NULL CHECK (condition IN ('good', 'fair', 'poor', 'withdrawn'))
);

CREATE TABLE loans (
    id          integer PRIMARY KEY,
    copy_id     integer NOT NULL REFERENCES copies (id),
    member_id   integer NOT NULL REFERENCES members (id),
    borrowed_on date NOT NULL,
    due_on      date NOT NULL,
    returned_on date,
    CONSTRAINT loans_due_after_borrowed CHECK (due_on > borrowed_on),
    CONSTRAINT loans_returned_after_borrowed
        CHECK (returned_on IS NULL OR returned_on >= borrowed_on)
);

-- A copy is out at most once at a time; returned loans do not block re-lending.
CREATE UNIQUE INDEX loans_one_open_per_copy ON loans (copy_id) WHERE returned_on IS NULL;

CREATE TABLE holds (
    id          integer PRIMARY KEY,
    title_id    integer NOT NULL REFERENCES titles (id),
    member_id   integer NOT NULL REFERENCES members (id),
    placed_on   date NOT NULL,
    released_on date,
    CONSTRAINT holds_released_after_placed
        CHECK (released_on IS NULL OR released_on >= placed_on)
);

CREATE UNIQUE INDEX holds_one_open_per_member_title
    ON holds (title_id, member_id) WHERE released_on IS NULL;

-- Rules 6 and 7 span tables, so they need triggers.

CREATE FUNCTION loans_lendable() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    cond   text;
    status text;
BEGIN
    SELECT c.condition INTO cond FROM copies c WHERE c.id = NEW.copy_id;
    IF cond = 'withdrawn' THEN
        RAISE EXCEPTION 'copy % is withdrawn and cannot be lent out', NEW.copy_id
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT m.status INTO status FROM members m WHERE m.id = NEW.member_id;
    IF status <> 'active' THEN
        RAISE EXCEPTION 'member % is % and cannot take out a loan', NEW.member_id, status
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER loans_lendable_trigger
    BEFORE INSERT ON loans
    FOR EACH ROW EXECUTE FUNCTION loans_lendable();

CREATE FUNCTION copies_withdrawable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.condition = 'withdrawn' AND OLD.condition <> 'withdrawn'
       AND EXISTS (SELECT 1 FROM loans l WHERE l.copy_id = NEW.id AND l.returned_on IS NULL)
    THEN
        RAISE EXCEPTION 'copy % is out on loan and cannot be withdrawn yet', NEW.id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER copies_withdrawable_trigger
    BEFORE UPDATE ON copies
    FOR EACH ROW EXECUTE FUNCTION copies_withdrawable();

-- Reporting.

CREATE FUNCTION overdue_as_of(p_as_of date)
RETURNS TABLE (loan_id integer, membership_no text, barcode text,
               title text, due_on date, days_overdue integer)
LANGUAGE sql STABLE AS $$
    SELECT l.id, m.membership_no, c.barcode, t.title, l.due_on,
           (p_as_of - l.due_on)::integer
    FROM loans l
    JOIN members m ON m.id = l.member_id
    JOIN copies  c ON c.id = l.copy_id
    JOIN titles  t ON t.id = c.title_id
    WHERE l.returned_on IS NULL
      AND l.due_on < p_as_of
    ORDER BY (p_as_of - l.due_on) DESC, c.barcode;
$$;

CREATE VIEW branch_stock AS
SELECT b.code                                    AS branch_code,
       t.isbn                                    AS isbn,
       count(*)::bigint                          AS total_copies,
       count(*) FILTER (
           WHERE EXISTS (SELECT 1 FROM loans l
                         WHERE l.copy_id = c.id AND l.returned_on IS NULL)
       )::bigint                                 AS on_loan,
       (count(*) - count(*) FILTER (
           WHERE EXISTS (SELECT 1 FROM loans l
                         WHERE l.copy_id = c.id AND l.returned_on IS NULL)
       ))::bigint                                AS available
FROM copies c
JOIN branches b ON b.id = c.branch_id
JOIN titles   t ON t.id = c.title_id
WHERE c.condition <> 'withdrawn'
GROUP BY b.code, t.isbn;
