---
title: API Style Guide
status: published
owner: Lena Okoro
updated: 2026-02-19
tags: api
---

# API Style Guide

Resource names are plural nouns. Collection endpoints paginate with an
opaque cursor; no endpoint has ever supported offset paging and none will.

Errors carry a stable machine-readable `code` and a human `message`. The
message may change between releases, the code may not.
