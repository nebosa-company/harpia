---
title: Backup standard
status: signed
updated: 2026-01-08
owner: Takeshi Mori
---

# Backup standard

Approved by the accountable owner. This is the document an auditor is
shown when they ask how backups are proven.

## Restore testing

Every backup set is restored into an isolated environment once a quarter
and the restored data is compared against the source. A restore that
cannot be completed is an incident, not a task.

The test is a restore, not a read of the backup catalogue. A backup that
has never been restored is a hypothesis.

## Backup window

The backup window is 35 days. A deletion request is honoured in the live
estate immediately and in the backups within that window, after which
the deletion must have reached the backups too.

## Scope

Every store holding customer data is in scope, including the ones that
are rebuilt from other stores, because the rebuild path has failed
before.
