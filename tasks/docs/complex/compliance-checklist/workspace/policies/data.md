---
area: Data
code: DAT
owner: Ayo Adeyemi
version: 3.1
approved: 2026-01-26
---

# Data handling policy

These policies cover what is kept, for how long, and what happens when
somebody asks for their data back. They are written to the statutory
clocks rather than to internal preference, and the internal targets are
deliberately shorter.

## DAT-01 Operational logs are kept for 90 days

Statement: Operational logs are retained for 90 days and deleted
automatically thereafter, with no manual extension available to any
individual.
Evidence: Retention configuration export from the log platform.
Controls: C-09

## DAT-02 Access logs are kept for 400 days

Statement: Access logs are retained for 400 days so that a full year of
activity remains available to an investigation, and are protected from
deletion by any operational process.
Evidence: Retention configuration export plus quarterly integrity check.
Controls: C-09, C-14

## DAT-03 Subject access requests are answered within 30 days

Statement: A subject access request is answered within the 30 day
statutory period, against an internal target of 10 days.
Evidence: Request register with received and answered dates.
Controls: C-10

## DAT-04 Backups are proven restorable

Statement: Every backup set is restored into an isolated environment at
least once a quarter and the restored data is compared against the
source.
Evidence: Restoration test record per backup set.
Controls: C-08
Withdrawn: 2025-12-01, superseded by OPS-04

## DAT-05 Personal data is minimised at collection

Statement: A field holding personal data is collected only where a named
purpose requires it, and the purpose is recorded in the data inventory
before collection begins.
Evidence: Data inventory entries with purpose and legal basis.
Controls: C-09
