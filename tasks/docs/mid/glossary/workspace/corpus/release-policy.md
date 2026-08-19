# Release policy

A service may release whenever it likes, subject to two conditions: the
change goes through a canary deploy, and the service has error budget
left to spend.

The error budget is the amount of unreliability a service is allowed
before it must stop shipping features and fix things instead. Ours is
0.1 percent of requests over a rolling 30 day window, which is roughly
43 minutes of total failure a month.

Release windows exist only for changes that cannot be canaried at all,
which in practice means schema migrations. Those go out on a Thursday
with the platform on-call rota informed in advance, and they carry a
runbook that a person who has never seen the migration can follow.

The person on the on-call rota is not the release manager and is never
expected to be. Their job during a release is to be reachable.
