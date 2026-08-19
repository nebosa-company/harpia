---
title: Postgres 16 Upgrade
status: draft
owner: Dmitri Sokolov
updated: 2026-03-02
tags: database, ops
---

# Postgres 16 Upgrade

Staging has been on 16 for eleven days with no regression in the nightly
query suite. The p99 on the checkout path dropped from 84 ms to 61 ms,
which is larger than we expected and worth confirming in production.

The replication slot monitor now alerts at 200 MB rather than 2 GB. That
alone would have caught the 15.4 incident.
