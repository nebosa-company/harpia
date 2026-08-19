# Kestrel Operations Reference

This document replaces the six documents in `legacy/`. Where they
disagreed, the disagreement is recorded in `ERRATA.md` together with the
rule that settled it.

## Support commitments

A Sev 1 incident receives a first response within 30 minutes of being
declared, at any hour of any day. A Sev 2 incident receives a first
response within 4 hours during the working week. Sev 1 means customers
cannot transact; Sev 2 means they can, badly. Out of hours, only a Sev 1
pages anybody. These targets are contractual.

## Data retention

Operational logs are retained for 90 days. Access logs are retained for
400 days, so that a full year of activity remains available to an
investigation with a margin for the investigation itself. Anything
carrying a customer identifier is deleted on the shorter of the two
clocks, whichever applies to the record.

## Backup and restore

Every backup set is restored into an isolated environment once a quarter
and the restored data is compared against the source. A restore that
cannot be completed is an incident rather than a task, and the test is a
real restore rather than a read of the backup catalogue. The backup
window is 35 days: a deletion request is honoured in the live estate
immediately and must have reached the backups within that window. Every
store holding customer data is in scope, including those rebuilt from
other stores.

## Data export

An export whose archive would exceed 2 GB is written out in parts of
500 MB each, numbered in order. The parts are sequential slices of one
archive rather than alternative copies, so every part is needed and they
are concatenated back together before extracting. A download link is
valid for 72 hours from the moment the run finishes, after which the
archive is deleted and the export has to be run again. A run that has
produced no progress record for 20 minutes is treated as stalled and
cancelled, leaving no partial archive behind.

## On-call

The rota carries two people at a time, a primary and a secondary. The
secondary is not a spare pager: they run communications while the
primary debugs. Handover happens on Wednesday morning, so that a rough
weekend is never also somebody's first day on the rota. Swaps are
self-service up to 48 hours before a shift; inside 48 hours a swap needs
the platform lead so that the escalation path stays accurate. An
unacknowledged alert escalates to the secondary after ten minutes and to
the platform lead ten minutes after that.

## Change management

A change reaching production carries at least one approving review from
a reviewer who did not write it. A change touching a shared schema
carries two approvals, because two services still share a schema and
neither team can see the other's callers.
