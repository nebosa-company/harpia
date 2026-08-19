# Incident handling

Declare early. The incident commander is the person who owns the
timeline, the communications and the question of who is doing what next.
They do not debug: the moment the commander is deep in a stack trace,
nobody is running the incident.

Severity is decided by blast radius rather than by cause. A bug that
affects one customer is a bug; the same bug behind a shared cache is an
incident, because the blast radius is everybody on that cache.

Two incidents in the last year came from the same place. The session
cluster hit its maxmemory ceiling of 8 GB and began evicting live
sessions; the ceiling has since been raised to 12 GB. A read-replica
failover stalled because the replication slot had grown past the point
where the standby could catch up.

The replication slot monitor now alerts at 200 MB rather than 2 GB,
which would have caught the second one.

Every incident ends with a written review, and every review that finds a
missing runbook produces one.
