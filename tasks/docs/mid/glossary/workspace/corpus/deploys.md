# How we deploy

Every service in the payments group ships through the same pipeline. A
canary deploy takes five percent of production traffic for ten minutes
while the gate watches the golden signal dashboard; if latency, traffic,
errors and saturation all stay inside their thresholds the change is
promoted to the rest of the fleet.

The point of holding at five percent is blast radius. A change that is
wrong is wrong for one customer in twenty for ten minutes, rather than
for everybody at once, and that is the difference between a bad morning
and an incident.

Rollback is a pipeline action. Every service keeps a runbook in its
repository describing what the rollback actually does, because "click
rollback" is not a plan when the previous version has a schema migration
behind it.

The gate consumes the service's error budget rather than a fixed error
count. A service that has already spent its budget this period cannot
promote a canary deploy at all until the window rolls over.
