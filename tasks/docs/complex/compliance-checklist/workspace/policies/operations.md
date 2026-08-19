---
area: Operations
code: OPS
owner: Takeshi Mori
version: 5.4
approved: 2026-02-11
---

# Operations policy

Operational policy is deliberately short. Each statement exists because
something went wrong once and the review that followed asked for it in
writing.

## OPS-01 Every production change is reviewed

Statement: A change reaching production carries at least one approving
review from somebody who did not write it, and a change touching a
shared schema carries two.
Evidence: Pull request records showing approvals per production change.
Controls: C-12

## OPS-02 Alerts route to the on-call rota

Statement: Every alert that requires a human routes to the on-call rota
rather than to an individual or to a mailbox, and an alert with no
documented action is removed rather than muted.
Evidence: Alert routing export with owner and runbook link per alert.
Controls: C-14

## OPS-03 Incident response is exercised twice a year

Statement: The incident process is exercised at least twice a year with
a scenario nobody taking part has seen in advance.
Evidence: Exercise report including timeline and follow-up actions.
Controls: C-13

## OPS-04 Deploys are reversible

Statement: Every deploy can be reversed by a pipeline action without a
manual edit, and a change that cannot be reversed that way is released
behind a flag instead.
Evidence: Pipeline configuration plus quarterly rollback drill record.
Controls: C-12

## OPS-05 Monitoring covers every production service

Statement: Every production service reports the four golden signals, and
a service that reports none of them is not considered in production.
Evidence: Monitoring coverage report listing signals per service.
Controls: C-14
