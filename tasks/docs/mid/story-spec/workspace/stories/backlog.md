# Billing console backlog

Stories are written by the billing product manager and reviewed at the
Thursday refinement. A story that the review turns down keeps its number
so that older meeting notes still resolve, but its status is set to
`rejected` and nothing is built from it.

## US-01: Save a draft invoice

Status: accepted

As a billing clerk I want to save an invoice before it is complete, so
that I can come back to it later without losing the work.

Acceptance criteria:

- A draft invoice can be saved with no line items at all.
- A draft invoice is never visible to the customer.
- Saving a draft does not allocate an invoice number.

## US-02: Approve an invoice

Status: accepted

As a billing supervisor I want to approve an invoice, so that it becomes
a real document with a number that finance can rely on.

Acceptance criteria:

- Approval requires a user holding the approver role.
- Approving allocates the next invoice number in sequence.
- An approved invoice can no longer be edited.

## US-03: Void an invoice

Status: accepted

As a billing supervisor I want to void an invoice raised in error, so
that it stops being chased without disappearing from the record.

Acceptance criteria:

- Voiding is possible only before the invoice is paid.
- A voided invoice keeps its number and is marked void.

## US-04: Search invoices

Status: accepted

As a billing clerk I want to find an invoice quickly, so that I can
answer a customer while they are still on the phone.

Acceptance criteria:

- Invoices can be searched by customer name.
- Invoices can be searched by invoice number.
- Search results are limited to 200 rows per page.
- Search covers the last 36 months unless a wider range is chosen.

## US-05: Print a batch of invoices

Status: rejected

As a billing clerk I want to print a month of invoices at once, so that
I can post the paper copies together.

Acceptance criteria:

- A batch print covers one calendar month.
- The batch is produced as a single PDF.

Rejected at refinement: two customers still take paper and both have
agreed to move to email during the quarter.

## US-06: Record a partial payment

Status: accepted

As a billing clerk I want to record a payment that does not clear the
invoice, so that the remaining balance is right.

Acceptance criteria:

- A payment smaller than the balance leaves the invoice partly paid.
- The remaining balance is recalculated after every payment.
- A payment larger than the balance is rejected.

## US-07: Export invoices to CSV

Status: accepted

As a finance analyst I want invoices as CSV, so that I can reconcile
them against the ledger without retyping anything.

Acceptance criteria:

- The export contains one row per invoice line.
- Amounts are exported in minor units as integers.

## US-08: Raise a credit note

Status: accepted

As a billing supervisor I want to issue a credit note, so that a
correction is visible rather than hidden by an edit.

Acceptance criteria:

- A credit note references exactly one invoice.
- A credit note cannot exceed the invoice total.
- Issuing a credit note leaves the original invoice unchanged.

## US-09: Customer billing profile

Status: accepted

As a billing clerk I want each customer to have one billing profile, so
that invoices are addressed from a single place.

Acceptance criteria:

- A profile holds one registered address and one billing email.
- Changing the address does not alter invoices already approved.
- A profile cannot be deleted while an unpaid invoice exists.

## US-10: Dunning reminders

Status: accepted

As a credit controller I want overdue invoices chased automatically, so
that I only handle the ones that stay unpaid.

Acceptance criteria:

- A reminder is sent 7 days after the due date.
- No more than 3 reminders are sent for one invoice.

## US-11: Multi-currency invoices

Status: rejected

As a billing supervisor I want to issue an invoice in the customer's own
currency, so that they are not paying conversion fees.

Acceptance criteria:

- An invoice carries a currency chosen at approval.
- Reporting converts every invoice to the reporting currency.

Rejected at refinement: the tax treatment is not settled and the finance
director wants it out of scope until it is.

## US-12: Audit trail

Status: accepted

As an auditor I want every change recorded, so that a dispute can be
settled from the record rather than from memory.

Acceptance criteria:

- Every state change records the actor and a timestamp.
- Audit entries cannot be edited or deleted.
- The audit trail is retained for 7 years.
