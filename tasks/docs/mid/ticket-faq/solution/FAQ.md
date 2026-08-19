# Support FAQ

## Accounts

### How do I transfer account ownership to someone else?

The current owner starts the transfer themselves. The person receiving
ownership has to hold the admin role already, so promote them to admin
first if they do not. The change takes effect immediately, and the
previous owner keeps the admin role rather than losing access. If the
original owner cannot be reached at all, the transfer runs through the
account's registered billing contact instead, which is slower and
handled manually.

Source: SUP-4110

### Why can I not remove the last admin on the account?

An account has to keep at least one admin at all times, so the console
refuses to demote or remove the final one. To hand the role over,
promote the incoming admin first and then demote the outgoing one.

Source: SUP-4111

## Billing

### Why did my invoice change in the middle of the billing period?

Because seats were added part way through it. Seat changes are prorated
to the day, so you are charged for the portion of the period the extra
seats were actually held. The prorated amount appears on the next
invoice as its own line rather than being folded into the subscription
line, which is why it can look unfamiliar. The seat history on the
account shows exactly when the change happened.

Source: SUP-4101, SUP-4102

### Can an invoice be re-issued with corrected details?

Yes, while the invoice is still inside the same tax year as the
original; it is re-issued with the corrected details and the same
invoice number. Once an invoice is outside its tax year it cannot be
re-issued at all, and the correction is made instead with a credit note
against the original plus a fresh invoice.

Source: SUP-4103

## Data Export

### Why did my export arrive as several files?

An export whose total size would go over 2 GB is written out in parts of
500 MB each, numbered in order. The parts are sequential slices of one
archive rather than alternative copies, so you need all of them, and
they are concatenated back together before extracting.

Source: SUP-4120, SUP-4121

### How long is an export download link valid?

72 hours from the moment the export finishes, after which the stored
archive is deleted and the links stop working. An expired export cannot
be revived and has to be run again, so it is worth starting long exports
early in the week. The completion email states the expiry time.

Source: SUP-4122

## Integrations

### Why does the same webhook event arrive more than once?

Delivery is at-least-once by design, so a repeated delivery is expected
rather than a fault. Every delivery carries a `delivery_id` header that
stays the same across retries of one event, and consumers are expected
to record it and ignore repeats. Key your idempotency table on
`delivery_id` rather than on a hash of the payload.

Source: SUP-4130, SUP-4131

### How long does the platform keep retrying a failed webhook?

A failed delivery is retried five times after the first attempt, spaced
1, 2, 4, 8 and 15 minutes apart, so the final retry lands 30 minutes
after the original attempt. Anything still failing at that point is
marked undelivered and appears in the integration log.

Source: SUP-4132

### Which addresses do webhook calls come from?

Webhook deliveries originate from two published ranges, 203.0.113.0/24
and 198.51.100.0/24. They have not changed since 2023, and any change is
announced at least 30 days in advance on the status page.

Source: SUP-4133
