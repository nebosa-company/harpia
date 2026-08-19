# Data handling

Operational logs are kept 90 days and access logs 400 days. Anything
carrying a customer identifier is deleted on the shorter of the two
clocks, whichever applies to the record.

A subject access request has a 30 day statutory clock. Internally we
target 10 days, which leaves three weeks for the requests that turn out
to be complicated — a subject access request covering a deleted account
usually is.

Backups are excluded from a deletion request only for the length of the
backup window, which is 35 days. After that the deletion has to have
reached the backups too, and the runbook for proving it is in the
platform repository.

Nothing in this document is affected by which cluster a service runs on
or how it deploys.
