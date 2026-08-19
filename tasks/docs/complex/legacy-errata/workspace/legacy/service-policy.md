---
title: Service policy
status: signed
updated: 2025-11-04
owner: Ayo Adeyemi
---

# Service policy

The commitments in this document are contractual. They were approved by
the accountable owner on the date above and are not changed by anything
written elsewhere.

## Incident response commitments

A Sev 1 incident receives a first response within 30 minutes of being
declared, at any hour of any day. A Sev 2 incident receives a first
response within 4 hours during the working week.

Sev 1 means customers cannot transact. Sev 2 means they can, badly.

## Log retention

Operational logs are retained for 90 days. Access logs are retained for
400 days, so that a full year of activity remains available to an
investigation with a margin for the investigation itself.

Anything carrying a customer identifier is deleted on the shorter of the
two clocks, whichever applies to the record.

## Change control

A change reaching production carries at least one approving review from
a reviewer who did not write it. A change touching a shared schema
carries two approvals, because two services still share a schema and
neither team can see the other's callers.
