# Platform Sync 2026-03-04

## Attendees

- Priya Raman (Engineering Manager)
- Dmitri Sokolov (Staff Engineer)
- Hannah Steiner (Platform Lead)
- Lena Okoro (Build Engineer)
- Takeshi Mori (Site Reliability Engineer)
- Ayo Adeyemi (Director of Engineering)

## Decisions

| ID | Decision | Owner |
| --- | --- | --- |
| D1 | Ship the Postgres 16 upgrade to production in the 12 March release window. | Dmitri Sokolov |
| D2 | Canary deploys become mandatory for all services in the payments group starting 1 April. | Hannah Steiner |
| D3 | Raise the Redis maxmemory ceiling from 8 GB to 12 GB on the session cluster. | Takeshi Mori |
| D4 | Defer the second SRE requisition to Q3. | Ayo Adeyemi |

## Action Items

| ID | Action | Owner | Due |
| --- | --- | --- | --- |
| A1 | Publish the upgrade runbook. | Dmitri Sokolov | 2026-03-09 |
| A2 | Schedule the read-replica cutover rehearsal. | Hannah Steiner | 2026-03-11 |
| A3 | Add canary gates to the payments CI templates. | Lena Okoro | 2026-03-13 |
| A4 | File the capacity change request. | Takeshi Mori | 2026-03-05 |
| A5 | Update the hiring plan document. | Ayo Adeyemi | 2026-03-17 |

## Open Questions

- Do we need a separate rollback window for the analytics replica?
- Who pages when a canary stalls at 5 percent?
- Should session data move off Redis entirely in H2?
