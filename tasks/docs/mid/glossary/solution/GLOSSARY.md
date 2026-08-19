# Glossary

## Terms

### blast radius

How much of the estate a change or a fault can damage. Severity is
decided by blast radius rather than by cause, which is why a canary is
held at five percent of traffic: a wrong change is wrong for one
customer in twenty for ten minutes instead of for everybody at once.

Occurs in: deploys.md, incidents.md

### canary deploy

A release that is given five percent of production traffic for ten
minutes while the gate watches the golden signal dashboard, and is
promoted to the rest of the fleet only if latency, traffic, errors and
saturation all stay inside their thresholds.

Occurs in: deploys.md, onboarding.md, release-policy.md

### error budget

The amount of unreliability a service is allowed before it must stop
shipping features and fix things instead: 0.1 percent of requests over a
rolling 30 day window, roughly 43 minutes of total failure a month. A
service that has spent its budget cannot promote a canary until the
window rolls over.

Occurs in: deploys.md, release-policy.md

### golden signal

One of the four measures the deploy gate watches: latency, traffic,
errors and saturation. A canary is promoted only while all four stay
inside their thresholds.

Occurs in: deploys.md, onboarding.md

### incident commander

The person who owns an incident's timeline, its communications and the
question of who does what next. The commander deliberately does not
debug, because a commander deep in a stack trace is nobody running the
incident.

Occurs in: incidents.md, onboarding.md

### maxmemory

The memory ceiling configured on a cache cluster, at which it starts
evicting live data. The session cluster hit its 8 GB ceiling and began
evicting sessions; the ceiling has since been raised to 12 GB.

Occurs in: incidents.md

### on-call rota

The rotation of people reachable for alerts. The person on the rota is
not the release manager and is not expected to be: during a release
their job is to be reachable. New engineers shadow the rota without
carrying the pager.

Occurs in: onboarding.md, release-policy.md

### replication slot

The server-side marker that tracks how far a standby has consumed the
write-ahead stream. One failover stalled because the slot had grown past
the point where the standby could catch up; the monitor now alerts at
200 MB rather than 2 GB.

Occurs in: incidents.md

### runbook

A written procedure a person who has never seen the change can follow.
Every service keeps one for its rollback, schema migrations carry one,
and every incident review that finds a missing runbook produces one.

Occurs in: data-handling.md, deploys.md, incidents.md, onboarding.md, release-policy.md

### subject access request

A request from a data subject for the personal data held about them. It
carries a 30 day statutory clock, against an internal target of 10 days,
which leaves three weeks for the complicated ones.

Occurs in: data-handling.md

## Not found

- dark launch
- shadow traffic
