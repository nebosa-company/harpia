# Branch library — database requirements

The schema goes in `schema.sql`. `seed.sql` is applied straight afterwards and
is written against the names below, so they are a contract, not a suggestion.

## Tables

**`branches`** — `id` (integer, primary key), `code` (text, unique),
`name` (text, required).

**`members`** — `id` (integer, primary key), `membership_no` (text, unique),
`full_name` (text, required), `joined_on` (date, required), `status` (text,
required, one of `active`, `suspended`, `closed`).

**`titles`** — `id` (integer, primary key), `isbn` (text, unique),
`title` (text, required), `author` (text, required), `published_year`
(integer, required, between 1450 and 2100 inclusive).

**`copies`** — `id` (integer, primary key), `title_id` (the title this is a
copy of), `branch_id` (the branch that holds it), `barcode` (text, unique,
exactly eight digits and nothing else), `condition` (text, required, one of
`good`, `fair`, `poor`, `withdrawn`).

**`loans`** — `id` (integer, primary key), `copy_id`, `member_id`,
`borrowed_on` (date, required), `due_on` (date, required),
`returned_on` (date, empty while the copy is still out).

**`holds`** — `id` (integer, primary key), `title_id`, `member_id`,
`placed_on` (date, required), `released_on` (date, empty while the hold is
still standing).

Every reference above must be a real foreign key: a copy cannot name a title
or a branch that does not exist, a loan cannot name a copy or a member that
does not exist, and neither can a hold.

## Rules the database must enforce

1. `due_on` is strictly after `borrowed_on`.
2. `returned_on`, when present, is on or after `borrowed_on`.
3. `released_on`, when present, is on or after `placed_on`.
4. A copy is out on at most one loan at a time: a copy may not appear on two
   loans that both have an empty `returned_on`. Once returned, it may be lent
   again any number of times.
5. A member holds a given title at most once at a time: no two holds for the
   same member and title may both have an empty `released_on`.
6. A copy whose condition is `withdrawn` may not be lent out. Withdrawing a
   copy that is already out is likewise refused — it has to come back first.
7. A member whose status is not `active` may not take out a new loan.
   Returning a copy is always allowed, whatever the member's status.

## Reporting

**Function `overdue_as_of(p_as_of date)`** returning rows of
`(loan_id integer, membership_no text, barcode text, title text, due_on date, days_overdue integer)`.
Every loan that is still out (`returned_on` empty) and whose `due_on` is
strictly before `p_as_of`. `days_overdue` is the number of days between
`due_on` and `p_as_of`. Ordered by `days_overdue` descending, then `barcode`
ascending.

**View `branch_stock(branch_code, isbn, total_copies, on_loan, available)`**
One row per branch and title for which the branch holds at least one copy
that is not `withdrawn`. `total_copies` counts that branch's copies of the
title excluding withdrawn ones, `on_loan` counts how many of those are
currently out, and `available` is the difference.
