---
title: Search Architecture
status: draft
updated: 2026-02-03
tags: search, architecture
---

# Search Architecture

The catalogue index is rebuilt nightly and patched incrementally through
the day from the change feed. Facet counts are cached for five minutes,
which is the single largest source of "the number moved" tickets.

Query parsing is deliberately dumb: quoted phrases, a leading minus for
negation, nothing else.
