# Engineering Handbook

The handbook is the answer to "how do we do this here". It is short on
principles and long on specifics, because the specifics are what people
actually need at eleven at night.

## Working Agreements

The agreements below are the ones the team has actually agreed to. An
agreement nobody follows is deleted rather than restated more firmly.

### Code Review

Two reviewers for anything that touches a shared schema, one otherwise.
A review is a conversation with a deadline: if it has not started within
one working day, the author may ask for it to be reassigned.

### Pairing

Pairing is a tool, not a policy. Use it for unfamiliar code, incident
follow-ups, and anything where the cost of getting it wrong is measured
in customer trust.

## Delivery

Delivery covers everything between a merged commit and a customer seeing
the change.

### Code Review

Release branches follow the same review rules as trunk, with one
addition: the reviewer must be someone who is not on call that week.

### Release Trains

Trains leave on Tuesday and Thursday. Missing a train is fine. Holding a
train for one change is not, because the next request always follows.

## Operations

### On-call

Primary and secondary, one week each, handover on Wednesday morning so
that a rough weekend is not also somebody's first day.

### Incident Response (Sev 1 & Sev 2)

Sev 1 means customers cannot transact. Sev 2 means they can, badly.
Declaring is cheap and un-declaring is cheaper; the expensive mistake is
waiting to be sure.

## Data & Privacy

### Retention

Operational logs 90 days, access logs 400 days, anything with customer
identifiers on the shorter clock of the two.

### Access Requests

A subject access request has a 30-day statutory clock and an internal
10-day target, so that the last three weeks exist for the awkward cases.

## FAQ

### Code Review

*Can I approve my own change?* No. *Can I merge an approved change on
someone else's behalf?* Yes, if they asked you to and the approval is
still current.
